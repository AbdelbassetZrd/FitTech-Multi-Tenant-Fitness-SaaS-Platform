"use client";

import React, { useState, useEffect, useMemo } from "react";
import { useRouter } from "next/navigation";
import AdminHeader from "@/components/admin/AdminHeader";
import StatCard from "@/components/admin/StatCard";
import { useAuthStore } from "@/lib/stores/authStore";
import {
  getAdminMembersApi,
  getAdminCoachesApi,
  getAdminSessionsApi,
  getAdminCoursesApi,
  getAdminSubscriptionsApi,
  getAdminPaymentsApi,
  getEquipmentStatsApi,
  User,
  CoachProfile,
  Session,
  Course,
  Subscription,
  Payment,
  EquipmentStats,
} from "@/lib/api";
import { getCapacityColor } from "@/lib/utils";

/* ── Bar Chart Component (Now dynamic) ───────────────────────────────── */
function BarChart({ payments, subscriptions }: { payments: Payment[]; subscriptions: Subscription[] }) {
  const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
  const now = new Date();
  // Show last 7 months including current
  const displayMonths: { label: string; monthIdx: number; year: number }[] = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    displayMonths.push({ label: months[d.getMonth()], monthIdx: d.getMonth(), year: d.getFullYear() });
  }

  const data = displayMonths.map(({ label, monthIdx, year }) => {
    const revenue = payments
      .filter((p) => p.status === "completed" && p.paid_at)
      .filter((p) => {
        const d = new Date(p.paid_at!);
        return d.getMonth() === monthIdx && d.getFullYear() === year;
      })
      .reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);

    const members = subscriptions.filter((s) => {
      const d = new Date(s.created_at);
      return d.getMonth() === monthIdx && d.getFullYear() === year;
    }).length;

    return { month: label, revenue, members };
  });

  const maxVal = Math.max(...data.map((d) => Math.max(d.revenue, d.members)), 1);

  return (
    <div className="flex items-end gap-4 h-56 px-2">
      {data.map((d, i) => (
        <div key={d.month} className="flex-1 flex flex-col items-center gap-1">
          <div className="w-full flex items-end gap-1 h-48">
            {/* Revenue bar */}
            <div
              className="flex-1 bg-brand-green/80 rounded-t-md transition-all duration-700 hover:bg-brand-green relative group cursor-pointer"
              style={{
                height: `${Math.max(4, (d.revenue / maxVal) * 100)}%`,
                animationDelay: `${i * 100}ms`,
              }}
            >
              <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-[#1a2332] text-white text-[10px] font-bold px-2 py-1 rounded-md opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                {d.revenue.toLocaleString()} DA
              </div>
            </div>
            {/* Members bar */}
            <div
              className="flex-1 bg-brand-green/30 rounded-t-md transition-all duration-700 relative group cursor-pointer"
              style={{ height: `${Math.max(4, (d.members / maxVal) * 100)}%` }}
            >
              <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-[#1a2332] text-white text-[10px] font-bold px-2 py-1 rounded-md opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10">
                {d.members} subs
              </div>
            </div>
          </div>
          <span className={`text-[10px] font-bold tracking-wider ${i === data.length - 1 ? 'text-brand-green' : 'text-text-muted/50'}`}>
            {d.month}
          </span>
        </div>
      ))}
    </div>
  );
}

/* ── Activity Feed Item ───────────────────────────────────────────────── */
function ActivityItem({ icon, iconBg, title, description, time }: {
  icon: React.ReactNode;
  iconBg: string;
  title: string;
  description: string;
  time: string;
}) {
  return (
    <div className="flex items-start gap-3 py-3 border-b border-white/5 last:border-0">
      <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${iconBg}`}>
        {icon}
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-semibold text-white">{title}</p>
        <p className="text-xs text-text-muted mt-0.5">{description}</p>
        <p className="text-[10px] font-bold text-text-muted/50 uppercase tracking-wider mt-1">{time}</p>
      </div>
    </div>
  );
}

/* ── Time-ago helper ──────────────────────────────────────────────────── */
function timeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return "Just now";
  if (mins < 60) return `${mins} min${mins > 1 ? "s" : ""} ago`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours} hour${hours > 1 ? "s" : ""} ago`;
  const days = Math.floor(hours / 24);
  return `${days} day${days > 1 ? "s" : ""} ago`;
}

/* ── Main Dashboard Page ──────────────────────────────────────────────── */
export default function AdminDashboardPage() {
  const router = useRouter();
  const accessToken = useAuthStore((s) => s.accessToken);

  const [members, setMembers] = useState<User[]>([]);
  const [coaches, setCoaches] = useState<CoachProfile[]>([]);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [courses, setCourses] = useState<Course[]>([]);
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [equipmentStats, setEquipmentStats] = useState<EquipmentStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!accessToken) return;
    const fetchAll = async () => {
      try {
        setLoading(true);
        const [membersData, coachesData, sessionsData, coursesData, subsData, paymentsData, eqStats] =
          await Promise.all([
            getAdminMembersApi(accessToken),
            getAdminCoachesApi(accessToken),
            getAdminSessionsApi(accessToken),
            getAdminCoursesApi(accessToken),
            getAdminSubscriptionsApi(accessToken),
            getAdminPaymentsApi(accessToken).catch(() => [] as Payment[]),
            getEquipmentStatsApi(accessToken).catch(() => null),
          ]);
        setMembers(membersData);
        setCoaches(coachesData);
        setSessions(sessionsData);
        setCourses(coursesData);
        setSubscriptions(subsData);
        setPayments(paymentsData);
        setEquipmentStats(eqStats);
      } catch {
        // silently handle — stats will show 0
      } finally {
        setLoading(false);
      }
    };
    fetchAll();
  }, [accessToken]);

  /* ── Computed stats ──────────────────────────────────────────────────── */

  const totalRevenue = useMemo(
    () => payments.filter((p) => p.status === "completed").reduce((s, p) => s + (parseFloat(p.amount) || 0), 0),
    [payments],
  );

  const activeMembers = useMemo(
    () => members.filter((m) => !m.is_suspended).length,
    [members],
  );

  const today = new Date().toISOString().split("T")[0];

  const todaySessions = useMemo(
    () => sessions.filter((s) => s.date === today && !s.is_cancelled),
    [sessions, today],
  );

  const totalAttendanceToday = useMemo(
    () => todaySessions.reduce((s, x) => s + (x.confirmed_count || 0), 0),
    [todaySessions],
  );

  const totalCapacityToday = useMemo(
    () => todaySessions.reduce((s, x) => s + (x.max_members || 0), 0),
    [todaySessions],
  );

  const attendanceRate = totalCapacityToday > 0
    ? Math.round((totalAttendanceToday / totalCapacityToday) * 100)
    : 0;

  /* ── Build activity feed from real data ─────────────────────────────── */

  const activityItems = useMemo(() => {
    const items: { icon: React.ReactNode; iconBg: string; title: string; description: string; time: string; sortDate: string }[] = [];

    // Recent subscriptions → "New member signup"
    subscriptions
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
      .slice(0, 2)
      .forEach((sub) => {
        items.push({
          icon: <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 text-brand-green"><path strokeLinecap="round" strokeLinejoin="round" d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z" /></svg>,
          iconBg: "bg-brand-green/15",
          title: "New subscription",
          description: `${sub.user_name || "A member"} subscribed to '${sub.plan?.name || "a plan"}'`,
          time: timeAgo(sub.created_at),
          sortDate: sub.created_at,
        });
      });

    // Recent payments → "Payment processed"
    payments
      .filter((p) => p.status === "completed")
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
      .slice(0, 2)
      .forEach((pay) => {
        items.push({
          icon: <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 text-blue-400"><path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z" /></svg>,
          iconBg: "bg-blue-500/15",
          title: "Payment processed",
          description: `${parseFloat(pay.amount).toLocaleString()} DA from ${pay.member_name || "a member"}`,
          time: timeAgo(pay.created_at),
          sortDate: pay.created_at,
        });
      });

    // Equipment alerts
    if (equipmentStats && equipmentStats.under_repair > 0) {
      items.push({
        icon: <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 text-red-400"><path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" /></svg>,
        iconBg: "bg-red-500/15",
        title: "Equipment Alert",
        description: `${equipmentStats.under_repair} unit${equipmentStats.under_repair > 1 ? "s" : ""} under repair`,
        time: "Current",
        sortDate: new Date().toISOString(),
      });
    }

    return items.sort((a, b) => new Date(b.sortDate).getTime() - new Date(a.sortDate).getTime()).slice(0, 4);
  }, [subscriptions, payments, equipmentStats]);

  /* ── Recent members (for Active Member Profiles) ────────────────────── */

  const recentActiveMembers = useMemo(() => {
    return members
      .filter((m) => !m.is_suspended)
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime())
      .slice(0, 3);
  }, [members]);

  /* ── Coach schedule (today) ─────────────────────────────────────────── */

  const courseMap = useMemo(() => {
    const m: Record<number, Course> = {};
    courses.forEach((c) => (m[c.id] = c));
    return m;
  }, [courses]);

  const coachScheduleToday = useMemo(() => {
    return todaySessions.slice(0, 3).map((s) => {
      const course = courseMap[s.course];
      const coachName = s.coach_name || course?.coach_name || "Unknown";
      const className = s.course_name || course?.name || "Session";
      const timeStr = course?.time || "—";
      const endMinutes = timeStr !== "—" ? (() => {
        const [h, m] = timeStr.split(":").map(Number);
        const total = h * 60 + m + (s.duration_time || 60);
        return `${String(Math.floor(total / 60)).padStart(2, "0")}:${String(total % 60).padStart(2, "0")}`;
      })() : "—";

      const now = new Date();
      const sessionDate = new Date(s.date + "T00:00:00");
      let status = "Upcoming";
      if (sessionDate < new Date(now.toDateString())) status = "Completed";
      else if (timeStr !== "—") {
        const [h] = timeStr.split(":").map(Number);
        if (now.getHours() > h) status = "Completed";
        else if (now.getHours() === h) status = "In Progress";
      }

      return { name: coachName, class: className, time: `${timeStr.slice(0, 5)} - ${endMinutes}`, status };
    });
  }, [todaySessions, courseMap]);

  /* ── Loading skeleton ───────────────────────────────────────────────── */

  if (loading) {
    return (
      <>
        <AdminHeader searchPlaceholder="Search members, schedules, or equipment..." actionLabel="+ New Member" />
        <div className="p-6 md:p-8 flex items-center justify-center min-h-[60vh]">
          <div className="flex flex-col items-center gap-4">
            <div className="w-10 h-10 rounded-full border-2 border-brand-green/20 border-t-brand-green animate-spin" />
            <p className="text-text-muted text-sm animate-pulse">Loading dashboard data...</p>
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      <AdminHeader searchPlaceholder="Search members, schedules, or equipment..." actionLabel="+ New Member" />

      <div className="p-6 md:p-8 space-y-6 animate-fade-in-up">
        {/* Page Title */}
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-3xl font-black text-white">Analytics Overview</h1>
            <p className="text-sm text-text-muted mt-1">Real-time performance metrics from your backend data</p>
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <StatCard
            label="Total Revenue"
            value={`${totalRevenue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} DA`}
            subtitle={`From ${payments.filter(p => p.status === "completed").length} completed payments`}
            icon={
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5 text-brand-green">
                <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0zm3 0h.008v.008H18V10.5zm-12 0h.008v.008H6V10.5z" />
              </svg>
            }
            extra={
              <div className="h-1 w-20 bg-white/5 rounded-full mt-1 overflow-hidden">
                <div className="h-full w-3/4 bg-brand-green rounded-full" />
              </div>
            }
          />
          <StatCard
            label="Active Members"
            value={activeMembers.toLocaleString()}
            subtitle={`${members.length} total registered`}
            icon={
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5 text-brand-green">
                <path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />
              </svg>
            }
            extra={
              <div className="flex -space-x-2">
                {["bg-brand-green", "bg-blue-500", "bg-amber-500"].map((bg, i) => (
                  <div key={i} className={`w-6 h-6 rounded-full ${bg} border-2 border-[#111827] text-[8px] font-bold text-white flex items-center justify-center`}>
                    {i === 2 ? `+${activeMembers > 100 ? Math.floor(activeMembers / 100) / 10 + "k" : activeMembers}` : ""}
                  </div>
                ))}
              </div>
            }
          />
          <StatCard
            label="Attendance Rate"
            value={`${attendanceRate}%`}
            subtitle={`${totalAttendanceToday} of ${totalCapacityToday} slots filled today`}
            valueColor=""
            valueStyle={{ color: getCapacityColor(attendanceRate) }}
            icon={
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5 text-brand-green">
                <path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" />
              </svg>
            }
            extra={
              <div className="flex gap-1 mt-1">
                {[...Array(5)].map((_, i) => (
                  <div key={i} className="w-5 h-6 rounded-sm transition-all duration-500" style={{ 
                    backgroundColor: getCapacityColor(attendanceRate),
                    opacity: Math.min(1, (attendanceRate / 100) + (i * 0.05)) 
                  }} />
                ))}
              </div>
            }
          />
        </div>

        {/* Charts + Activity Row */}
        <div className="grid grid-cols-1 lg:grid-cols-[1fr_340px] gap-4">
          {/* Growth Chart */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-lg font-bold text-white">Growth & Revenue Trends</h2>
              <div className="flex items-center gap-4 text-xs">
                <span className="flex items-center gap-1.5 text-text-muted">
                  <span className="w-2.5 h-2.5 rounded-full bg-brand-green" /> Revenue
                </span>
                <span className="flex items-center gap-1.5 text-text-muted">
                  <span className="w-2.5 h-2.5 rounded-full bg-brand-green/30" /> New Subs
                </span>
              </div>
            </div>
            <BarChart payments={payments} subscriptions={subscriptions} />
          </div>

          {/* Recent Activity */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
            <h2 className="text-lg font-bold text-white mb-4">Recent Activity</h2>
            <div className="space-y-0">
              {activityItems.length === 0 ? (
                <p className="text-sm text-text-muted py-4 text-center">No recent activity found.</p>
              ) : (
                activityItems.map((item, i) => (
                  <ActivityItem key={i} {...item} />
                ))
              )}
            </div>
            <button onClick={() => router.push('/admin/reports')} className="w-full mt-4 py-2.5 text-center text-sm font-semibold text-text-muted border border-white/5 rounded-xl hover:bg-white/5 hover:text-white transition-all duration-300">
              View All Activity
            </button>
          </div>
        </div>

        {/* Bottom Row: Active Members + Coach Schedule */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {/* Active Member Profiles */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-white">Active Member Profiles</h2>
              <button onClick={() => router.push('/admin/members')} className="text-sm font-semibold text-brand-green hover:text-brand-green-light transition-colors">View All Members</button>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="text-[10px] font-bold tracking-wider text-text-muted/50 uppercase">
                  <th className="text-left pb-3">Member</th>
                  <th className="text-left pb-3">Plan</th>
                  <th className="text-left pb-3">Status</th>
                  <th className="text-left pb-3">Joined</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {recentActiveMembers.length === 0 ? (
                  <tr><td colSpan={4} className="py-4 text-center text-text-muted text-xs">No active members yet.</td></tr>
                ) : (
                  recentActiveMembers.map((m) => {
                    // Find the member's active subscription
                    const sub = subscriptions.find((s) => s.user_name === `${m.first_name} ${m.last_name}` && s.status === "active");
                    const planName = sub?.plan?.name || "—";
                    return (
                      <tr key={m.id} className="hover:bg-white/3 transition-colors">
                        <td className="py-3 flex items-center gap-2">
                          <div className="w-8 h-8 rounded-full bg-brand-green/20 flex items-center justify-center text-brand-green text-xs font-bold">
                            {(m.first_name?.[0] || "").toUpperCase()}
                          </div>
                          <span className="font-medium text-white">{m.first_name} {m.last_name}</span>
                        </td>
                        <td className="py-3 text-text-muted">{planName}</td>
                        <td className="py-3">
                          <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${!m.is_suspended ? "bg-brand-green/15 text-brand-green" : "bg-red-500/15 text-red-400"}`}>
                            {!m.is_suspended ? "Active" : "Suspended"}
                          </span>
                        </td>
                        <td className="py-3 text-text-muted text-xs">
                          {new Date(m.created_at).toLocaleDateString("en-US", { month: "short", day: "numeric" })}
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>

          {/* Coach Schedule */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-lg font-bold text-white">Coach Schedule (Today)</h2>
              <button onClick={() => router.push('/admin/courses')} className="px-3 py-1.5 text-xs font-bold text-text-muted border border-white/10 rounded-lg hover:bg-white/5 hover:text-white transition-all">Manage All</button>
            </div>
            <div className="space-y-3">
              {coachScheduleToday.length === 0 ? (
                <p className="text-sm text-text-muted py-4 text-center">No sessions scheduled for today.</p>
              ) : (
                coachScheduleToday.map((s, i) => (
                  <div key={i} className="flex items-center gap-3 p-3 rounded-xl bg-white/3 hover:bg-white/5 transition-colors">
                    <div className="w-9 h-9 rounded-full bg-brand-green/20 flex items-center justify-center text-brand-green text-xs font-bold">
                      {s.name.split(" ").map((n: string) => n[0]).join("").slice(0, 2).toUpperCase()}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-white">{s.name}</p>
                      <p className="text-xs text-text-muted">{s.class} · {s.time}</p>
                    </div>
                    <span className={`text-[10px] font-bold uppercase tracking-wider px-2 py-1 rounded-md ${
                      s.status === "Completed" ? "bg-brand-green/10 text-brand-green" :
                      s.status === "In Progress" ? "bg-blue-500/10 text-blue-400" :
                      "bg-white/5 text-text-muted"
                    }`}>
                      {s.status}
                    </span>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
