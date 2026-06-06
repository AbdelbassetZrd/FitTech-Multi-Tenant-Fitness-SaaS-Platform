/* ─── API Client ─────────────────────────────────────────────────────────── */

const API_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

/* ── Types ─────────────────────────────────────────────────────────────── */

export interface User {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  full_name: string;
  phone: string;
  date_of_birth: string | null;
  photo: string | null;
  role: "member" | "coach" | "admin";
  fitness_goal: string;
  medical_restrictions: string;
  email_verified: boolean;
  is_suspended: boolean;
  suspension_end_date: string | null;
  warnings_count: number;
  bio: string;
  is_newsletter_subscribed: boolean;
  profile_completion_percentage: number;
  is_profile_complete: boolean;
  is_suspension_active: boolean;
  created_at: string;
  last_login: string | null;
}

export interface AuthTokens {
  access: string;
  refresh: string;
}

export interface LoginResponse extends AuthTokens {
  user: User;
}

export interface RegisterResponse {
  message: string;
  user_id: string;
  email: string;
}

export interface ApiError {
  error?: string;
  detail?: string;
  needs_verification?: boolean;
  [key: string]: unknown;
}

/* ── Fetch wrapper ─────────────────────────────────────────────────────── */

export async function apiFetch<T>(
  endpoint: string,
  options: RequestInit = {},
  accessToken?: string | null,
): Promise<T> {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };

  if (accessToken) {
    headers["Authorization"] = `Bearer ${accessToken}`;
  }

  const res = await fetch(`${API_URL}${endpoint}`, {
    ...options,
    headers,
  });

  // Handle 204 No Content
  if (res.status === 204) {
    return {} as T;
  }

  let data;
  const contentType = res.headers.get("content-type");
  try {
    if (contentType && contentType.includes("application/json")) {
      data = await res.json();
    } else {
      data = { detail: `HTTP ${res.status}: ${res.statusText} (Non-JSON response)` };
    }
  } catch (e) {
    data = { error: "Failed to parse API response." };
  }

  if (!res.ok) {
    const err = new Error(
      data.error || data.detail || "Something went wrong",
    ) as Error & { status: number; data: ApiError };
    err.status = res.status;
    err.data = data;
    throw err;
  }

  return data as T;
}

/* ── Auth API functions ────────────────────────────────────────────────── */

export async function loginApi(email: string, password: string): Promise<LoginResponse> {
  // We determine whether to hit admin or member endpoints. 
  // Typically an admin might have a specific email or we can try sequentially.
  if (email.includes('admin')) {
    const res = await apiFetch<{ access: string; refresh: string }>("/api/auth/admin/login/", {
      method: "POST",
      body: JSON.stringify({ email, password }),
    });
    return {
      access: res.access,
      refresh: res.refresh,
      user: {
        id: "admin",
        email: email,
        full_name: "System Admin",
        first_name: "System",
        last_name: "Admin",
        role: "admin",
        phone: "",
        date_of_birth: null,
        photo: null,
        fitness_goal: "",
        medical_restrictions: "",
        email_verified: true,
        is_suspended: false,
        suspension_end_date: null,
        warnings_count: 0,
        bio: "",
        is_newsletter_subscribed: false,
        profile_completion_percentage: 100,
        is_profile_complete: true,
        is_suspension_active: false,
      } as User
    };
  }

  return apiFetch<LoginResponse>("/api/auth/members/login/", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
}

export function registerApi(payload: {
  email: string;
  password: string;
  password2: string;
  first_name: string;
  last_name: string;
  phone?: string;
  role?: string;
}) {
  return apiFetch<RegisterResponse>("/api/auth/members/register/", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function refreshTokenApi(refreshToken: string) {
  return apiFetch<{ access: string }>("/api/auth/token/refresh/", {
    method: "POST",
    body: JSON.stringify({ refresh: refreshToken }),
  });
}

export function logoutApi(refreshToken: string, accessToken: string) {
  return apiFetch<{ message: string }>(
    "/api/auth/members/logout/",
    {
      method: "POST",
      body: JSON.stringify({ refresh_token: refreshToken }),
    },
    accessToken,
  );
}

export async function getProfileApi(accessToken: string): Promise<User> {
  try {
    return await apiFetch<User>("/api/auth/members/profile/", { method: "GET" }, accessToken);
  } catch (err: any) {
    // If member profile fails, it might be an admin
    if (err.status === 401 || err.status === 404 || err.status === 403) {
      try {
        return await apiFetch<User>("/api/auth/admin/profile/", { method: "GET" }, accessToken);
      } catch (adminErr) {
        throw adminErr;
      }
    }
    throw err;
  }
}

export function verifyEmailApi(key: string) {
  return apiFetch<{ message: string; access: string; refresh: string; user: User }>(
    `/api/auth/members/verify-email/${key}/`,
    { method: "GET" },
  );
}

export function resendVerificationApi(email: string) {
  return apiFetch<{ message: string }>("/api/auth/members/resend-verification/", {
    method: "POST",
    body: JSON.stringify({ email }),
  });
}

export function resetPasswordRequestApi(email: string) {
  return apiFetch<{ message: string }>("/api/auth/members/password/reset/", {
    method: "POST",
    body: JSON.stringify({ email }),
  });
}

export function resetPasswordConfirmApi(
  token: string,
  new_password: string,
  new_password2: string,
) {
  return apiFetch<{ message: string }>("/api/auth/members/password/reset/confirm/", {
    method: "POST",
    body: JSON.stringify({ token, new_password, new_password2 }),
  });
}

export function updateProfileApi(
  payload: Partial<User>,
  accessToken: string,
) {
  return apiFetch<User>("/api/auth/members/profile/update/", {
    method: "PATCH",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function changePasswordApi(
  payload: { old_password: string; new_password: string; new_password2: string },
  accessToken: string,
) {
  return apiFetch<{ message: string }>("/api/auth/members/password/change/", {
    method: "POST",
    body: JSON.stringify(payload),
  }, accessToken);
}

/* ── Admin Coach management ────────────────────────────────────────────── */

export interface CoachProfile {
  id: string;
  email: string;
  first_name: string;
  last_name: string;
  phone: string;
  photo: string | null;
  specialities: string;
  bio: string;
  years_of_experience: number;
  is_active: boolean;
  is_available: boolean;
  last_login: string | null;
  created_at: string;
}

export function getAdminCoachesApi(accessToken: string) {
  return apiFetch<CoachProfile[]>("/api/auth/admin/coaches/", {
    method: "GET",
  }, accessToken);
}

export function createAdminCoachApi(payload: Partial<CoachProfile> & { password?: string }, accessToken: string) {
  return apiFetch<CoachProfile>("/api/auth/admin/coaches/create/", {
    method: "POST",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function updateAdminCoachApi(id: string, payload: Partial<CoachProfile>, accessToken: string) {
  return apiFetch<CoachProfile>(`/api/auth/admin/coaches/${id}/`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function deleteAdminCoachApi(id: string, accessToken: string) {
  return apiFetch<{ message: string }>(`/api/auth/admin/coaches/${id}/`, {
    method: "DELETE",
  }, accessToken);
}

/* ── Admin Member management ───────────────────────────────────────────── */

export function getAdminMembersApi(accessToken: string) {
  return apiFetch<User[]>("/api/auth/admin/members/", {
    method: "GET",
  }, accessToken);
}

export function createAdminMemberApi(payload: Partial<User> & { password?: string }, accessToken: string) {
  return apiFetch<User>("/api/auth/admin/members/create/", {
    method: "POST",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function searchAdminMembersApi(query: string, accessToken: string) {
  return apiFetch<User[]>(`/api/auth/admin/members/search/?q=${encodeURIComponent(query)}`, {
    method: "GET",
  }, accessToken);
}

export function suspendAdminMemberApi(id: string | number, accessToken: string) {
  return apiFetch<{ message: string }>(`/api/auth/admin/members/${id}/suspend/`, {
    method: "POST",
  }, accessToken);
}

export function removeSuspensionAdminMemberApi(id: string | number, accessToken: string) {
  return apiFetch<{ message: string }>(`/api/auth/admin/members/${id}/remove-suspension/`, {
    method: "POST",
  }, accessToken);
}

export function assignNFCDeviceApi(
  payload: { user_id: string; uid: string; device_type?: string; role?: string },
  accessToken: string,
) {
  return apiFetch<{ message: string; device_id: number }>("/api/access/assign/", {
    method: "POST",
    body: JSON.stringify(payload),
  }, accessToken);
}

export interface NFCDevice {
  id: number;
  uid: string;
  device_type: string;
  role: string;
  owner_name: string;
  is_active: boolean;
  created_at: string;
}

export function listNFCDevicesApi(accessToken: string, role?: string) {
  const q = role ? `?role=${role}` : '';
  return apiFetch<{ results: NFCDevice[] }>(`/api/access/devices/${q}`, { method: 'GET' }, accessToken);
}

export function deactivateNFCDeviceApi(uid: string, accessToken: string) {
  return apiFetch<{ message: string }>('/api/access/deactivate/', {
    method: 'POST',
    body: JSON.stringify({ uid }),
  }, accessToken);
}

/* ── Equipment management ──────────────────────────────────────────────── */

export interface Equipment {
  id: number | string;
  name: string;
  category: string;
  status: string;
  status_display?: string;
  last_maintenance_date?: string;
  created_at?: string;
  updated_at?: string;
}

export interface EquipmentStats {
  total: number;
  active: number;
  under_repair: number;
  out_of_order: number;
}

export function getEquipmentListApi(accessToken: string) {
  return apiFetch<Equipment[]>("/api/equipment/", {
    method: "GET",
  }, accessToken);
}

export function getEquipmentStatsApi(accessToken: string) {
  return apiFetch<EquipmentStats>("/api/equipment/stats/", {
    method: "GET",
  }, accessToken);
}

export function createEquipmentApi(payload: Partial<Equipment>, accessToken: string) {
  return apiFetch<Equipment>("/api/equipment/create/", {
    method: "POST",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function updateEquipmentApi(id: string | number, payload: Partial<Equipment>, accessToken: string) {
  return apiFetch<Equipment>(`/api/equipment/${id}/update/`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function deleteEquipmentApi(id: string | number, accessToken: string) {
  return apiFetch<{}>(`/api/equipment/${id}/delete/`, {
    method: "DELETE",
  }, accessToken);
}

export function markEquipmentActiveApi(id: string | number, accessToken: string) {
  return apiFetch<Equipment>(`/api/equipment/${id}/mark-active/`, {
    method: "POST",
  }, accessToken);
}

export function markEquipmentUnderRepairApi(id: string | number, accessToken: string) {
  return apiFetch<Equipment>(`/api/equipment/${id}/under-repair/`, {
    method: "PATCH",
  }, accessToken);
}

export function markEquipmentOutOfOrderApi(id: string | number, accessToken: string) {
  return apiFetch<Equipment>(`/api/equipment/${id}/out-of-order/`, {
    method: "PATCH",
  }, accessToken);
}

export interface MaintenanceLog {
  id: number | string;
  equipment: number | string;
  equipment_name?: string;
  date: string;
  title: string;
  technician: string;
  parts_cost: string | null;
  status: string;
  created_at: string;
}

export function getRecentMaintenanceLogsApi(accessToken: string) {
  return apiFetch<MaintenanceLog[]>("/api/equipment/maintenance-logs/", {
    method: "GET",
  }, accessToken);
}

export function googleLoginApi(token: string): Promise<LoginResponse> {
  return apiFetch<LoginResponse>("/api/auth/members/users/auth/google/", {
    method: "POST",
    body: JSON.stringify({ token }),
  });
}

/* ── Courses & Sessions ────────────────────────────────────────────────── */

export interface Course {
  id: number;
  name: string;
  coach: string;
  coach_name?: string;
  time: string;
  day: string;
  max_members: number;
  number_of_sessions: number;
  session_price?: string;
  salle?: number;
  salle_name?: string;
}

export interface Session {
  id: number;
  course: number;
  course_name?: string;
  coach_name?: string;
  date: string;
  is_cancelled: boolean;
  notes: string;
  confirmed_count?: number;
  waiting_count?: number;
  is_full?: boolean;
  max_members?: number;
  salle?: string;
  salle_fk?: number;
  duration_time?: number;
}

export function getAdminSessionsApi(accessToken: string) {
  return apiFetch<Session[]>("/api/courses/admin/sessions/", {
    method: "GET",
  }, accessToken);
}

export function createAdminSessionApi(payload: Partial<Session>, accessToken: string) {
  return apiFetch<Session>("/api/courses/admin/sessions/create/", {
    method: "POST",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function updateAdminSessionApi(id: number | string, payload: Partial<Session>, accessToken: string) {
  return apiFetch<Session>(`/api/courses/admin/sessions/${id}/`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function deleteAdminSessionApi(id: number | string, accessToken: string) {
  return apiFetch<{ message: string }>(`/api/courses/admin/sessions/${id}/`, {
    method: "DELETE",
  }, accessToken);
}

export function getAdminCoursesApi(accessToken: string) {
  return apiFetch<Course[]>("/api/courses/admin/courses/", {
    method: "GET",
  }, accessToken);
}

export function createAdminCourseApi(payload: Partial<Course>, accessToken: string) {
  return apiFetch<Course>("/api/courses/admin/courses/create/", {
    method: "POST",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function updateAdminCourseApi(id: number | string, payload: Partial<Course>, accessToken: string) {
  return apiFetch<Course>(`/api/courses/admin/courses/${id}/`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function deleteAdminCourseApi(id: number | string, accessToken: string) {
  return apiFetch<{ message: string }>(`/api/courses/admin/courses/${id}/`, {
    method: "DELETE",
  }, accessToken);
}

/* ── Subscriptions & Plans ─────────────────────────────────────────────── */

export interface SubscriptionPlan {
  id: number;
  name: string;
  plan_type: string;
  price: string;
  times_per_week: number;
  duration_days: number | null;
  session_count: number | null;
  description: string;
  is_active: boolean;
  is_featured: boolean;
  features: string[];
  created_by_name?: string;
}

export interface Subscription {
  id: number;
  user_name?: string;
  plan?: SubscriptionPlan;
  plan_id?: number;
  status: string;
  start_date: string;
  end_date: string | null;
  sessions_remaining: number;
  pause_start_date: string | null;
  pause_end_date: string | null;
  total_pause_days_used: number;
  pause_days_remaining?: number;
  is_currently_active?: boolean;
  can_pause?: boolean;
  created_at: string;
}

export function getPublicPlansApi() {
  return apiFetch<SubscriptionPlan[]>("/api/subscriptions/plans/", {
    method: "GET",
  });
}

export function getAdminPlansApi(accessToken: string) {
  return apiFetch<SubscriptionPlan[]>("/api/subscriptions/admin/plans/", {
    method: "GET",
  }, accessToken);
}

export function createAdminPlanApi(payload: Partial<SubscriptionPlan>, accessToken: string) {
  return apiFetch<SubscriptionPlan>("/api/subscriptions/admin/plans/", {
    method: "POST",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function updateAdminPlanApi(id: number | string, payload: Partial<SubscriptionPlan>, accessToken: string) {
  return apiFetch<SubscriptionPlan>(`/api/subscriptions/admin/plans/${id}/`, {
    method: "PATCH",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function deleteAdminPlanApi(id: number | string, accessToken: string) {
  return apiFetch<{ message: string }>(`/api/subscriptions/admin/plans/${id}/`, {
    method: "DELETE",
  }, accessToken);
}

export function getAdminSubscriptionsApi(accessToken: string) {
  return apiFetch<Subscription[]>("/api/subscriptions/admin/subscriptions/", {
    method: "GET",
  }, accessToken);
}

/* ── Admin Payments ────────────────────────────────────────────────────── */

export interface Payment {
  id: number;
  subscription: number;
  subscription_plan?: string;
  member_name?: string;
  amount: string;
  payment_method: string;
  status: string;
  transaction_id: string;
  paid_at: string | null;
  created_at: string;
  has_invoice?: boolean;
}

export function getAdminPaymentsApi(accessToken: string) {
  return apiFetch<Payment[]>("/api/subscriptions/admin/payments/", {
    method: "GET",
  }, accessToken);
}

export function adminCreateSubscriptionApi(
  payload: { user_id: string; plan_id: number; payment_method?: string },
  accessToken: string,
) {
  return apiFetch<Subscription>("/api/subscriptions/admin/subscriptions/create/", {
    method: "POST",
    body: JSON.stringify(payload),
  }, accessToken);
}

export function adminUpdateSubscriptionPlanApi(
  subId: number | string,
  payload: { plan_id: number },
  accessToken: string,
) {
  return apiFetch<{ message: string; subscription: Subscription }>(
    `/api/subscriptions/admin/subscriptions/${subId}/update-plan/`,
    { method: "PATCH", body: JSON.stringify(payload) },
    accessToken,
  );
}

export function adminCancelSubscriptionApi(subId: number | string, accessToken: string) {
  return apiFetch<{ message: string; subscription: Subscription }>(
    `/api/subscriptions/admin/subscriptions/${subId}/cancel/`,
    { method: "POST" },
    accessToken,
  );
}

export function adminCreateManualPaymentApi(
  payload: {
    user_id?: string;
    amount: number;
    payment_method: string;
    category?: string;
    currency?: string;
    note?: string;
    guest_name?: string;
  },
  accessToken: string,
) {
  return apiFetch<{ message: string; transaction_id: string; payment?: Payment }>(
    "/api/subscriptions/admin/payments/manual/",
    { method: "POST", body: JSON.stringify(payload) },
    accessToken,
  );
}

/* ── Admin Salles ──────────────────────────────────────────────────────── */

export interface Salle {
  id: number;
  name: string;
  capacity?: number;
  is_available?: boolean;
}

export function getAdminSallesApi(accessToken: string) {
  return apiFetch<Salle[]>("/api/courses/admin/salles/", {
    method: "GET",
  }, accessToken);
}

export function getRoomsAvailabilityApi(day: string, time: string, accessToken?: string | null) {
  const qs = `?day=${encodeURIComponent(day)}&time=${encodeURIComponent(time)}`;
  return apiFetch<{ id: number; name: string; capacity: number; is_available: boolean; reason?: string }[]>(
    `/api/rooms/availability/${qs}`,
    { method: "GET" },
    accessToken,
  );
}

/* ── Rooms Admin (frontend) ───────────────────────────────────────────────── */

export function getRoomsApi(accessToken?: string | null) {
  const endpoint = accessToken ? "/api/rooms/admin/rooms/" : "/api/rooms/list/";
  return apiFetch<any[]>(endpoint, { method: "GET" }, accessToken);
}

export function createRoomApi(payload: any, accessToken?: string | null) {
  return apiFetch<any>("/api/rooms/admin/rooms/create/", { method: "POST", body: JSON.stringify(payload) }, accessToken);
}

export function updateRoomApi(id: number | string, payload: any, accessToken?: string | null) {
  return apiFetch<any>(`/api/rooms/admin/rooms/${id}/update/`, { method: "PUT", body: JSON.stringify(payload) }, accessToken);
}

export function deleteRoomApi(id: number | string, accessToken?: string | null) {
  return apiFetch<any>(`/api/rooms/admin/rooms/${id}/delete/`, { method: "DELETE" }, accessToken);
}


/* ── Messaging ─────────────────────────────────────────────────────────── */

export interface ChatContact {
  id: string;
  name: string;
  role: string;
  email: string;
  description?: string;
}

export interface ContactsResponse {
  current_user_id: string;
  contacts: ChatContact[];
}

export function getContactsApi(accessToken: string) {
  return apiFetch<ContactsResponse>("/api/messaging/contacts/", {
    method: "GET",
  }, accessToken);
}

/* ── Admin Notifications ────────────────────────────────────────────────── */

export interface AdminNotification {
  id: number;
  notification_type: string;
  title: string;
  message: string;
  is_read: boolean;
  created_at: string;
}

export function getAdminNotificationsApi(accessToken: string) {
  return apiFetch<AdminNotification[]>("/api/notifications/admin/", {
    method: "GET",
  }, accessToken);
}

export function markAdminNotificationReadApi(id: number, accessToken: string) {
  return apiFetch<{ detail: string }>(`/api/notifications/admin/${id}/read/`, {
    method: "POST",
  }, accessToken);
}

export function markAllAdminNotificationsReadApi(accessToken: string) {
  return apiFetch<{ detail: string }>("/api/notifications/admin/read-all/", {
    method: "POST",
  }, accessToken);
}
