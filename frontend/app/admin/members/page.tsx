"use client";

import React, { useState, useEffect, useMemo, useRef, useCallback } from "react";
import AdminHeader from "@/components/admin/AdminHeader";
import StatCard from "@/components/admin/StatCard";
import ConfirmModal from "@/components/admin/ConfirmModal";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/lib/stores/authStore";
import {
  getAdminMembersApi,
  createAdminMemberApi,
  suspendAdminMemberApi,
  removeSuspensionAdminMemberApi,
  assignNFCDeviceApi,
  User,
} from "@/lib/api";

export default function MembersPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const [members, setMembers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [searchQuery, setSearchQuery] = useState("");
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 8;

  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [memberToSuspend, setMemberToSuspend] = useState<User | null>(null);
  const [showFilters, setShowFilters] = useState(false);
  const [statusFilter, setStatusFilter] = useState<"all" | "active" | "suspended" | "unverified">("all");
  const [contextMenu, setContextMenu] = useState<{ mouseX: number; mouseY: number; member: User } | null>(null);
  const router = useRouter();

  // NFC capture polling
  const [nfcScanning, setNfcScanning] = useState(false);
  const nfcSessionId = useRef(`admin-${Date.now()}`);
  const nfcPollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const startNfcCapture = useCallback(() => {
    setNfcScanning(true);
    nfcSessionId.current = `default`;
    nfcPollRef.current = setInterval(async () => {
      try {
        const backendUrl = process.env.NEXT_PUBLIC_API_BASE_URL || "https://providing-april-manger.ngrok-free.dev";
        const res = await fetch(
          `${backendUrl}/api/access/capture-uid/?session_id=default`,
          { headers: { "ngrok-skip-browser-warning": "true", "Accept": "application/json" } },
        );
        const data = await res.json();
        if (data.uid) {
          setCreateForm((f) => ({ ...f, nfc_uid: data.uid }));
          stopNfcCapture();
        }
      } catch (_) {}
    }, 1000);
  }, []);

  const stopNfcCapture = useCallback(() => {
    setNfcScanning(false);
    if (nfcPollRef.current) {
      clearInterval(nfcPollRef.current);
      nfcPollRef.current = null;
    }
  }, []);

  useEffect(() => () => stopNfcCapture(), [stopNfcCapture]);

  // Create member state
  const [isAddModalOpen, setIsAddModalOpen] = useState(false);
  const [createError, setCreateError] = useState("");
  const [createForm, setCreateForm] = useState({
    email: "",
    password: "",
    first_name: "",
    last_name: "",
    phone: "",
    date_of_birth: "",
    fitness_goal: "",
    medical_restrictions: "",
    nfc_uid: "",
    nfc_device_type: "card",
  });

  const fetchMembers = async () => {
    if (!accessToken) return;
    try {
      setLoading(true);
      const data = await getAdminMembersApi(accessToken);
      setMembers(data);
      setError("");
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Failed to load members");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchMembers();
  }, [accessToken]);

  useEffect(() => {
    const handleGlobalClick = () => setContextMenu(null);
    window.addEventListener("click", handleGlobalClick);
    return () => window.removeEventListener("click", handleGlobalClick);
  }, []);

  /* ── Computed stats ─────────────────────────────────────────────────── */
  const stats = useMemo(() => {
    const total = members.length;
    const active = members.filter((m) => !m.is_suspended).length;
    const suspended = members.filter((m) => m.is_suspended).length;
    const unverified = members.filter((m) => !m.email_verified).length;
    return { total, active, suspended, unverified };
  }, [members]);

  /* ── Client-side search ─────────────────────────────────────────────── */
  const filteredMembers = useMemo(() => {
    let result = members;
    if (statusFilter === "active") {
      result = result.filter((m) => !m.is_suspended);
    } else if (statusFilter === "suspended") {
      result = result.filter((m) => m.is_suspended);
    } else if (statusFilter === "unverified") {
      result = result.filter((m) => !m.email_verified);
    }

    if (!searchQuery.trim()) return result;
    const q = searchQuery.toLowerCase();
    return result.filter(
      (m) => {
        const fullName = `${m.first_name || ""} ${m.last_name || ""}`.toLowerCase();
        const email = (m.email || "").toLowerCase();
        return fullName.includes(q) || email.includes(q);
      }
    );
  }, [members, searchQuery, statusFilter]);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchQuery, statusFilter]);

  const paginatedMembers = useMemo(() => {
    const startIndex = (currentPage - 1) * itemsPerPage;
    return filteredMembers.slice(startIndex, startIndex + itemsPerPage);
  }, [filteredMembers, currentPage]);

  /* ── Suspend / Unsuspend ────────────────────────────────────────────── */
  const promptSuspendAction = (member: User) => {
    setMemberToSuspend(member);
    setIsConfirmOpen(true);
  };

  const confirmSuspendAction = async () => {
    if (!accessToken || !memberToSuspend || actionLoading) return;
    try {
      setActionLoading(memberToSuspend.id);
      if (memberToSuspend.is_suspended) {
        await removeSuspensionAdminMemberApi(memberToSuspend.id, accessToken);
      } else {
        await suspendAdminMemberApi(memberToSuspend.id, accessToken);
      }
      await fetchMembers();
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Action failed");
    } finally {
      setActionLoading(null);
      setIsConfirmOpen(false);
      setMemberToSuspend(null);
    }
  };

  /* ── Create Member ──────────────────────────────────────────────────── */
  const handleCreateSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!accessToken) return;
    try {
      setActionLoading("create");
      setCreateError("");
      const payload: any = { ...createForm };
      if (!payload.date_of_birth) delete payload.date_of_birth;
      if (!payload.phone) delete payload.phone;
      if (!payload.fitness_goal) delete payload.fitness_goal;
      if (!payload.medical_restrictions) delete payload.medical_restrictions;
      delete payload.nfc_uid;
      delete payload.nfc_device_type;
      
      const created = await createAdminMemberApi(payload, accessToken);

      // Auto-assign NFC device if a UID was provided
      if (createForm.nfc_uid.trim()) {
        try {
          await assignNFCDeviceApi(
            {
              user_id: String(created.id),
              uid: createForm.nfc_uid.trim().toUpperCase(),
              device_type: createForm.nfc_device_type,
              role: "member",
            },
            accessToken,
          );
        } catch (nfcErr: any) {
          // Member was created OK; show NFC warning but don't block
          setCreateError(
            `Member created, but NFC assignment failed: ${
              nfcErr?.data?.error || nfcErr?.message || "Unknown error"
            }`,
          );
        }
      }

      setIsAddModalOpen(false);
      setCreateError("");
      setCreateForm({
        email: "",
        password: "",
        first_name: "",
        last_name: "",
        phone: "",
        date_of_birth: "",
        fitness_goal: "",
        medical_restrictions: "",
        nfc_uid: "",
        nfc_device_type: "card",
      });
      await fetchMembers();
    } catch (err: any) {
      // Parse field-level errors from DRF
      const data = err?.data;
      if (data && typeof data === "object" && !data.error && !data.detail) {
        const messages = Object.entries(data)
          .map(([field, msgs]: [string, any]) => `${field}: ${Array.isArray(msgs) ? msgs.join(", ") : msgs}`)
          .join("; ");
        setCreateError(messages || "Failed to create member");
      } else {
        setCreateError(data?.error || data?.detail || err?.message || "Failed to create member");
      }
    } finally {
      setActionLoading(null);
    }
  };

  /* ── Format date helper ─────────────────────────────────────────────── */
  const formatDate = (dateStr?: string | null) => {
    if (!dateStr) return "—";
    try {
      return new Date(dateStr).toLocaleDateString("en-US", {
        year: "numeric",
        month: "short",
        day: "numeric",
      });
    } catch {
      return "—";
    }
  };

  return (
    <>
      <AdminHeader 
        searchPlaceholder="Search members, activities, or records..." 
        actionLabel="Add Entry" 
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
      />

      <div className="p-6 md:p-8 space-y-6 animate-fade-in-up">
        {/* Breadcrumb */}
        <div>
          <p className="text-[10px] font-bold tracking-[0.2em] text-text-muted/50 uppercase">
            Admin <span className="text-brand-green">› Member Management</span>
          </p>
        </div>

        {/* Page Title */}
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-3xl font-black text-white">Member Management</h1>
            <p className="text-sm text-text-muted mt-1">Review and manage performance athlete profiles across all locations.</p>
          </div>
          <div className="flex items-center gap-3 relative">
            <button
              onClick={() => setShowFilters(!showFilters)}
              className={`flex items-center gap-2 px-4 py-2.5 border rounded-xl text-sm font-semibold transition-all ${
                showFilters || statusFilter !== "all"
                  ? "border-brand-green/50 text-brand-green bg-brand-green/10"
                  : "border-white/10 text-text-muted hover:text-white hover:bg-white/5"
              }`}
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" />
              </svg>
              FILTERS {statusFilter !== "all" && "(1)"}
            </button>

            {showFilters && (
              <div className="absolute top-[110%] right-[160px] w-48 bg-[#111827] border border-white/10 rounded-xl shadow-xl z-10 p-2 animate-fade-in-up">
                <p className="text-[10px] font-bold text-text-muted/50 uppercase tracking-wider px-2 py-1">Status</p>
                <div className="space-y-1">
                  <button onClick={() => setStatusFilter("all")} className={`w-full text-left px-2 py-1.5 rounded-lg text-sm transition-colors ${statusFilter === "all" ? "bg-white/10 text-white" : "text-text-muted hover:bg-white/5"}`}>All Members</button>
                  <button onClick={() => setStatusFilter("active")} className={`w-full text-left px-2 py-1.5 rounded-lg text-sm transition-colors ${statusFilter === "active" ? "bg-white/10 text-white" : "text-text-muted hover:bg-white/5"}`}>Active Only</button>
                  <button onClick={() => setStatusFilter("suspended")} className={`w-full text-left px-2 py-1.5 rounded-lg text-sm transition-colors ${statusFilter === "suspended" ? "bg-white/10 text-white" : "text-text-muted hover:bg-white/5"}`}>Suspended Only</button>
                  <button onClick={() => setStatusFilter("unverified")} className={`w-full text-left px-2 py-1.5 rounded-lg text-sm transition-colors ${statusFilter === "unverified" ? "bg-white/10 text-white" : "text-text-muted hover:bg-white/5"}`}>Unverified Only</button>
                </div>
              </div>
            )}

            <button
              onClick={() => setIsAddModalOpen(true)}
              className="flex items-center gap-2 px-5 py-2.5 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-bold transition-all duration-300 hover:shadow-lg hover:shadow-brand-green/20"
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z" />
              </svg>
              ADD NEW MEMBER
            </button>
          </div>
        </div>

        {/* Stats Grid — computed from real data */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard 
            label="Total Members" 
            value={String(stats.total)} 
            onClick={() => setStatusFilter("all")}
            isActive={statusFilter === "all"}
          />
          <StatCard
            label="Active Members"
            value={String(stats.active)}
            valueColor="text-brand-green"
            extra={
              <div className="flex -space-x-1.5">
                {["bg-brand-green", "bg-blue-500"].map((bg, i) => (
                  <div key={i} className={`w-5 h-5 rounded-full ${bg} border-2 border-[#111827]`} />
                ))}
              </div>
            }
            onClick={() => setStatusFilter("active")}
            isActive={statusFilter === "active"}
          />
          <StatCard 
            label="Suspended" 
            value={String(stats.suspended).padStart(2, '0')} 
            valueColor="text-red-500"
            onClick={() => setStatusFilter("suspended")}
            isActive={statusFilter === "suspended"}
          />
          <StatCard
            label="Unverified Email"
            value={String(stats.unverified).padStart(2, '0')}
            valueColor="text-amber-500"
            extra={
              stats.total > 0 ? (
                <div className="w-16 h-2 bg-white/5 rounded-full overflow-hidden">
                  <div
                    className="h-full bg-amber-500 rounded-full"
                    style={{ width: `${Math.round((stats.unverified / stats.total) * 100)}%` }}
                  />
                </div>
              ) : null
            }
            onClick={() => setStatusFilter("unverified")}
            isActive={statusFilter === "unverified"}
          />
        </div>

        {/* Error Banner */}
        {error && (
          <div className="bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3 flex items-center justify-between">
            <p className="text-sm text-red-400">{error}</p>
            <button onClick={() => setError("")} className="text-red-400 hover:text-red-300 text-xs font-bold">DISMISS</button>
          </div>
        )}

        {/* Member List */}
        <div className="bg-[#111827]/80 border border-white/5 rounded-2xl">
          {/* List Header with Search */}
          <div className="px-6 py-4 flex items-center justify-between border-b border-white/5">
            <div className="flex items-center gap-3">
              <h2 className="text-base font-bold text-white">MEMBER LIST</h2>
              <span className="text-xs text-text-muted">| {filteredMembers.length} member{filteredMembers.length !== 1 ? "s" : ""} found</span>
            </div>
            <div className="flex items-center gap-2">
              <button onClick={fetchMembers} className="p-2 rounded-lg hover:bg-white/5 text-text-muted/60 hover:text-white transition-colors" title="Refresh">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
                </svg>
              </button>
            </div>
          </div>

          {/* Table */}
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-[10px] font-bold tracking-[0.15em] text-text-muted/50 uppercase border-b border-white/5">
                  <th className="text-left px-6 py-3">Member Name</th>
                  <th className="text-left px-6 py-3">Status</th>
                  <th className="text-left px-6 py-3">Email Verified</th>
                  <th className="text-left px-6 py-3">Join Date</th>
                  <th className="text-right px-6 py-3">Actions</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={5} className="px-6 py-8 text-center text-text-muted">Loading members...</td>
                  </tr>
                ) : filteredMembers.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-6 py-8 text-center text-text-muted">
                      {searchQuery ? "No members match your search." : "No members found."}
                    </td>
                  </tr>
                ) : (
                  paginatedMembers.map((m) => (
                    <tr 
                      key={m.id} 
                      className="border-b border-white/5 hover:bg-white/[0.03] transition-colors cursor-context-menu"
                      onContextMenu={(e) => {
                        e.preventDefault();
                        setContextMenu({ mouseX: e.clientX, mouseY: e.clientY, member: m });
                      }}
                    >
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="w-10 h-10 rounded-full bg-white/10 border border-white/10 flex items-center justify-center text-white text-xs font-bold overflow-hidden">
                            {m.photo ? (
                              <img src={m.photo} alt={m.first_name} className="w-full h-full object-cover" />
                            ) : (
                              `${m.first_name?.[0] || ""}${m.last_name?.[0] || ""}`.toUpperCase()
                            )}
                          </div>
                          <div>
                            <p className="font-semibold text-white">{m.first_name} {m.last_name}</p>
                            <p className="text-xs text-text-muted">{m.email}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`flex items-center gap-1.5 text-sm font-medium ${!m.is_suspended ? "text-brand-green" : "text-red-400"}`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${!m.is_suspended ? "bg-brand-green" : "bg-red-400"}`} />
                          {!m.is_suspended ? "Active" : "Suspended"}
                        </span>
                      </td>
                      <td className="px-6 py-4">
                        <span className={`text-[10px] font-bold tracking-wider px-2.5 py-1 rounded-md ${m.email_verified ? "bg-brand-green/10 text-brand-green" : "bg-amber-500/10 text-amber-400"}`}>
                          {m.email_verified ? "VERIFIED" : "UNVERIFIED"}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-text-muted text-xs font-mono tracking-wider">
                        {formatDate(m.created_at)}
                      </td>
                      <td className="px-6 py-4">
                        <div className="flex items-center justify-end gap-2">
                          {/* Suspend / Unsuspend */}
                          <button
                            onClick={() => promptSuspendAction(m)}
                            disabled={actionLoading === m.id}
                            title={m.is_suspended ? "Remove Suspension" : "Suspend Member"}
                            className={`p-1.5 rounded-lg hover:bg-white/5 transition-colors ${
                              actionLoading === m.id
                                ? "opacity-50 cursor-not-allowed"
                                : m.is_suspended
                                  ? "text-amber-400 hover:text-amber-300"
                                  : "text-text-muted/60 hover:text-white"
                            }`}
                          >
                            {actionLoading === m.id ? (
                              <svg className="w-4 h-4 animate-spin" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
                              </svg>
                            ) : (
                              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
                              </svg>
                            )}
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          {/* Footer with real count */}
          <div className="px-6 py-4 flex flex-col md:flex-row items-center justify-between border-t border-white/5 gap-4">
            <span className="text-xs text-text-muted/50 uppercase tracking-wider">
              Showing {paginatedMembers.length} of {filteredMembers.length} member{filteredMembers.length !== 1 ? "s" : ""}
            </span>
            {filteredMembers.length > itemsPerPage && (
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1.5 rounded-lg border border-white/10 text-xs text-text-muted hover:text-white hover:bg-white/5 disabled:opacity-50 transition-colors"
                >
                  Previous
                </button>
                <span className="text-xs text-text-muted">
                  Page {currentPage} of {Math.ceil(filteredMembers.length / itemsPerPage)}
                </span>
                <button
                  onClick={() => setCurrentPage(p => Math.min(Math.ceil(filteredMembers.length / itemsPerPage), p + 1))}
                  disabled={currentPage >= Math.ceil(filteredMembers.length / itemsPerPage)}
                  className="px-3 py-1.5 rounded-lg border border-white/10 text-xs text-text-muted hover:text-white hover:bg-white/5 disabled:opacity-50 transition-colors"
                >
                  Next
                </button>
              </div>
            )}
          </div>
        </div>

        {/* Security Footer */}
        <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <div className="w-12 h-12 rounded-full bg-brand-green/10 flex items-center justify-center">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-6 h-6 text-brand-green">
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
              </svg>
            </div>
            <div>
              <p className="text-sm font-bold text-white">Security & Compliance Mode</p>
              <p className="text-xs text-text-muted mt-0.5">All member actions are logged and encrypted. Performance data access is restricted to authorized personnel only.</p>
            </div>
          </div>
          <button className="text-xs font-bold text-brand-green uppercase tracking-wider hover:text-brand-green-light transition-colors whitespace-nowrap">
            View Audit Logs
          </button>
        </div>
      </div>

      <ConfirmModal
        isOpen={isConfirmOpen}
        onClose={() => {
          setIsConfirmOpen(false);
          setMemberToSuspend(null);
        }}
        onConfirm={confirmSuspendAction}
        title={memberToSuspend?.is_suspended ? "Remove Suspension" : "Suspend Member"}
        message={
          memberToSuspend?.is_suspended
            ? `Are you sure you want to remove suspension for ${memberToSuspend?.first_name} ${memberToSuspend?.last_name}? They will regain full access to the application.`
            : `Are you sure you want to suspend ${memberToSuspend?.first_name} ${memberToSuspend?.last_name}? They will immediately lose access to the application.`
        }
        confirmText={memberToSuspend?.is_suspended ? "REMOVE SUSPENSION" : "SUSPEND"}
        isDestructive={!memberToSuspend?.is_suspended}
      />

      {contextMenu && (
        <div 
          className="fixed z-50 bg-[#111827] border border-white/10 rounded-xl shadow-2xl py-1 w-48 animate-fade-in-up"
          style={{ top: contextMenu.mouseY, left: contextMenu.mouseX }}
        >
          <button
            onClick={() => {
              // Handle Modify for members (placeholder if edit modal not fully implemented here yet)
              setContextMenu(null);
            }}
            className="w-full text-left px-4 py-2 text-sm text-text-muted hover:bg-white/10 hover:text-white transition-colors flex items-center gap-2"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
              <path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L6.832 19.82a4.5 4.5 0 01-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 011.13-1.897L16.863 4.487zM16.862 4.487L19.5 7.125" />
            </svg>
            Modify
          </button>
          <button
            onClick={() => {
              promptSuspendAction(contextMenu.member);
              setContextMenu(null);
            }}
            className="w-full text-left px-4 py-2 text-sm text-text-muted hover:bg-white/10 hover:text-white transition-colors flex items-center gap-2"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
              <path strokeLinecap="round" strokeLinejoin="round" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
            </svg>
            {contextMenu.member.is_suspended ? "Unsuspend" : "Suspend"}
          </button>
          <button
            onClick={() => {
              router.push(`/admin/messages?contactId=${contextMenu.member.id}`);
              setContextMenu(null);
            }}
            className="w-full text-left px-4 py-2 text-sm text-text-muted hover:bg-white/10 hover:text-white transition-colors flex items-center gap-2"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
              <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 12.76c0 1.6 1.123 2.994 2.707 3.227 1.087.16 2.185.283 3.293.369V21l4.076-4.076a1.526 1.526 0 011.037-.443 48.282 48.282 0 005.68-.494c1.584-.233 2.707-1.626 2.707-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0012 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018z" />
            </svg>
            Chat
          </button>
        </div>
      )}

      {/* Add New Member Modal */}
      {isAddModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-md p-4" onClick={() => { setIsAddModalOpen(false); setCreateError(""); }}>
          <div
            className="bg-gradient-to-b from-[#131c2e] to-[#0d1322] border border-white/[0.08] rounded-2xl w-full max-w-lg shadow-[0_25px_60px_rgba(0,0,0,0.5)] overflow-hidden animate-fade-in-up"
            onClick={(e) => e.stopPropagation()}
          >
            {/* Header */}
            <div className="relative px-6 pt-6 pb-4 border-b border-white/[0.06]">
              <div className="absolute top-0 left-0 right-0 h-[2px] bg-gradient-to-r from-transparent via-brand-green/60 to-transparent" />
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-brand-green/10 border border-brand-green/20 flex items-center justify-center">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5 text-brand-green">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z" />
                  </svg>
                </div>
                <div>
                  <h2 className="text-lg font-bold text-white">Add New Member</h2>
                  <p className="text-xs text-text-muted">Create a new athlete profile</p>
                </div>
              </div>
              <button onClick={() => { setIsAddModalOpen(false); setCreateError(""); }} className="absolute top-5 right-5 w-8 h-8 rounded-lg bg-white/5 hover:bg-white/10 flex items-center justify-center text-text-muted hover:text-white transition-all">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            {/* Body */}
            <div className="px-6 py-5 overflow-y-auto max-h-[calc(90vh-160px)]">
              {createError && (
                <div className="bg-red-500/10 border border-red-500/20 rounded-xl px-4 py-3 mb-5 flex items-start gap-3">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5 text-red-400 shrink-0 mt-0.5">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
                  </svg>
                  <p className="text-sm text-red-400 flex-1">{createError}</p>
                  <button onClick={() => setCreateError("")} className="text-red-400/60 hover:text-red-300 transition-colors"><svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4"><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg></button>
                </div>
              )}
              
              <form onSubmit={handleCreateSubmit} className="space-y-5">
                {/* Section: Identity */}
                <div>
                  <p className="text-[10px] font-bold text-text-muted/40 uppercase tracking-[0.2em] mb-3">Identity</p>
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-[11px] font-semibold text-text-muted/70 mb-1.5">First Name <span className="text-brand-green">*</span></label>
                      <input type="text" required value={createForm.first_name} onChange={(e) => setCreateForm({ ...createForm, first_name: e.target.value })} placeholder="John" className="w-full bg-white/[0.04] border border-white/[0.08] rounded-lg px-3.5 py-2.5 text-sm text-white placeholder-text-muted/30 focus:outline-none focus:border-brand-green/40 focus:ring-1 focus:ring-brand-green/20 transition-all" />
                    </div>
                    <div>
                      <label className="block text-[11px] font-semibold text-text-muted/70 mb-1.5">Last Name <span className="text-brand-green">*</span></label>
                      <input type="text" required value={createForm.last_name} onChange={(e) => setCreateForm({ ...createForm, last_name: e.target.value })} placeholder="Doe" className="w-full bg-white/[0.04] border border-white/[0.08] rounded-lg px-3.5 py-2.5 text-sm text-white placeholder-text-muted/30 focus:outline-none focus:border-brand-green/40 focus:ring-1 focus:ring-brand-green/20 transition-all" />
                    </div>
                  </div>
                </div>

                {/* Section: Credentials */}
                <div>
                  <p className="text-[10px] font-bold text-text-muted/40 uppercase tracking-[0.2em] mb-3">Credentials</p>
                  <div className="space-y-3">
                    <div>
                      <label className="block text-[11px] font-semibold text-text-muted/70 mb-1.5">Email Address <span className="text-brand-green">*</span></label>
                      <div className="relative">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-text-muted/30">
                          <path strokeLinecap="round" strokeLinejoin="round" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25m19.5 0v.243a2.25 2.25 0 01-1.07 1.916l-7.5 4.615a2.25 2.25 0 01-2.36 0L3.32 8.91a2.25 2.25 0 01-1.07-1.916V6.75" />
                        </svg>
                        <input type="email" required value={createForm.email} onChange={(e) => setCreateForm({ ...createForm, email: e.target.value })} placeholder="member@fittech.com" className="w-full bg-white/[0.04] border border-white/[0.08] rounded-lg pl-10 pr-3.5 py-2.5 text-sm text-white placeholder-text-muted/30 focus:outline-none focus:border-brand-green/40 focus:ring-1 focus:ring-brand-green/20 transition-all" />
                      </div>
                    </div>
                    <div>
                      <label className="block text-[11px] font-semibold text-text-muted/70 mb-1.5">Temporary Password <span className="text-brand-green">*</span></label>
                      <div className="relative">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-text-muted/30">
                          <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
                        </svg>
                        <input type="password" required minLength={8} value={createForm.password} onChange={(e) => setCreateForm({ ...createForm, password: e.target.value })} placeholder="Min. 8 characters" className="w-full bg-white/[0.04] border border-white/[0.08] rounded-lg pl-10 pr-3.5 py-2.5 text-sm text-white placeholder-text-muted/30 focus:outline-none focus:border-brand-green/40 focus:ring-1 focus:ring-brand-green/20 transition-all" />
                      </div>
                      <p className="text-[10px] text-text-muted/40 mt-1.5 flex items-center gap-1">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-3 h-3"><path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" /></svg>
                        User will be prompted to change on first login
                      </p>
                    </div>
                  </div>
                </div>

                {/* Section: NFC Access */}
                <div>
                  <p className="text-[10px] font-bold text-text-muted/40 uppercase tracking-[0.2em] mb-3">NFC Access Card</p>
                  <div className="bg-white/[0.02] border border-white/[0.06] rounded-xl p-4 space-y-3">
                    <div>
                      <label className="block text-[11px] font-semibold text-text-muted/70 mb-1.5">
                        NFC Card UID
                        <span className="ml-2 text-text-muted/40 font-normal">(optional)</span>
                      </label>

                      {/* Scan button row */}
                      <div className="flex gap-2 mb-2">
                        {!nfcScanning ? (
                          <button
                            type="button"
                            onClick={startNfcCapture}
                            className="flex items-center gap-2 px-4 py-2.5 rounded-lg bg-brand-green/15 border border-brand-green/30 text-brand-green text-xs font-bold hover:bg-brand-green/25 transition-all"
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z" />
                            </svg>
                            Scan Card
                          </button>
                        ) : (
                          <button
                            type="button"
                            onClick={stopNfcCapture}
                            className="flex items-center gap-2 px-4 py-2.5 rounded-lg bg-yellow-500/10 border border-yellow-500/30 text-yellow-400 text-xs font-bold hover:bg-yellow-500/20 transition-all"
                          >
                            <span className="w-2 h-2 rounded-full bg-yellow-400 animate-pulse" />
                            Waiting for card… (cancel)
                          </button>
                        )}
                      </div>

                      {/* UID display / manual input */}
                      <div className="relative">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-brand-green/50">
                          <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z" />
                        </svg>
                        <input
                          type="text"
                          value={createForm.nfc_uid}
                          onChange={(e) => setCreateForm({ ...createForm, nfc_uid: e.target.value.toUpperCase() })}
                          placeholder={nfcScanning ? "Tap card on reader…" : "Auto-filled on scan · or type manually"}
                          className={`w-full bg-white/[0.04] border rounded-lg pl-10 pr-3.5 py-2.5 text-sm text-white placeholder-text-muted/30 focus:outline-none transition-all font-mono tracking-wider ${
                            nfcScanning
                              ? "border-yellow-500/40 focus:border-yellow-500/60 focus:ring-1 focus:ring-yellow-500/20"
                              : createForm.nfc_uid
                              ? "border-brand-green/40 focus:border-brand-green/60 focus:ring-1 focus:ring-brand-green/20"
                              : "border-white/[0.08] focus:border-brand-green/40 focus:ring-1 focus:ring-brand-green/20"
                          }`}
                        />
                        {createForm.nfc_uid && (
                          <button
                            type="button"
                            onClick={() => setCreateForm({ ...createForm, nfc_uid: "" })}
                            className="absolute right-3 top-1/2 -translate-y-1/2 text-text-muted/40 hover:text-white transition-colors"
                          >
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-3.5 h-3.5"><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
                          </button>
                        )}
                      </div>
                      <p className="text-[10px] text-text-muted/40 mt-1.5">
                        Press <span className="text-brand-green/70 font-semibold">Scan Card</span>, then tap the physical NFC card on your reader — the UID fills automatically.
                      </p>
                    </div>
                    <div>
                      <label className="block text-[11px] font-semibold text-text-muted/70 mb-1.5">Device Type</label>
                      <div className="flex gap-2">
                        {(["card", "phone"] as const).map((t) => (
                          <button
                            key={t}
                            type="button"
                            onClick={() => setCreateForm({ ...createForm, nfc_device_type: t })}
                            className={`flex-1 py-2 rounded-lg text-xs font-bold transition-all border ${
                              createForm.nfc_device_type === t
                                ? "bg-brand-green/15 border-brand-green/40 text-brand-green"
                                : "bg-white/[0.03] border-white/[0.08] text-text-muted hover:border-white/20"
                            }`}
                          >
                            {t === "card" ? "🪪  Physical Card" : "📱  Phone NFC"}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>

                {/* Section: Details */}
                <div>
                  <p className="text-[10px] font-bold text-text-muted/40 uppercase tracking-[0.2em] mb-3">Details</p>
                  <div className="space-y-3">
                    <div className="grid grid-cols-2 gap-3">
                      <div>
                        <label className="block text-[11px] font-semibold text-text-muted/70 mb-1.5">Phone Number</label>
                        <input type="tel" value={createForm.phone} onChange={(e) => setCreateForm({ ...createForm, phone: e.target.value })} placeholder="+213 555 1234" className="w-full bg-white/[0.04] border border-white/[0.08] rounded-lg px-3.5 py-2.5 text-sm text-white placeholder-text-muted/30 focus:outline-none focus:border-brand-green/40 focus:ring-1 focus:ring-brand-green/20 transition-all" />
                      </div>
                      <div>
                        <label className="block text-[11px] font-semibold text-text-muted/70 mb-1.5">Date of Birth</label>
                        <input type="date" value={createForm.date_of_birth} onChange={(e) => setCreateForm({ ...createForm, date_of_birth: e.target.value })} className="w-full bg-white/[0.04] border border-white/[0.08] rounded-lg px-3.5 py-2.5 text-sm text-white focus:outline-none focus:border-brand-green/40 focus:ring-1 focus:ring-brand-green/20 transition-all" style={{ colorScheme: "dark" }} />
                      </div>
                    </div>
                    <div>
                      <label className="block text-[11px] font-semibold text-text-muted/70 mb-1.5">Fitness Goal</label>
                      <div className="relative">
                        <select value={createForm.fitness_goal} onChange={(e) => setCreateForm({ ...createForm, fitness_goal: e.target.value })} className="w-full bg-white/[0.04] border border-white/[0.08] rounded-lg px-3.5 py-2.5 pr-10 text-sm text-white focus:outline-none focus:border-brand-green/40 focus:ring-1 focus:ring-brand-green/20 transition-all appearance-none cursor-pointer" style={{ colorScheme: "dark" }}>
                          <option value="">Select a goal…</option>
                          <option value="weight_loss">🏃 Weight Loss</option>
                          <option value="muscle_gain">💪 Muscle Gain</option>
                          <option value="endurance">🫀 Endurance</option>
                          <option value="flexibility">🧘 Flexibility</option>
                          <option value="general">⚡ General Fitness</option>
                        </select>
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 absolute right-3.5 top-1/2 -translate-y-1/2 text-text-muted/40 pointer-events-none">
                          <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
                        </svg>
                      </div>
                    </div>
                  </div>
                </div>

                {/* Footer */}
                <div className="pt-3 border-t border-white/[0.06] flex justify-end gap-3">
                  <button type="button" onClick={() => { setIsAddModalOpen(false); setCreateError(""); }} className="px-5 py-2.5 rounded-xl text-sm font-semibold text-text-muted hover:text-white hover:bg-white/5 transition-all">
                    Cancel
                  </button>
                  <button type="submit" disabled={actionLoading === "create"} className="px-6 py-2.5 bg-gradient-to-r from-brand-green to-emerald-400 hover:from-brand-green-light hover:to-emerald-300 text-[#0B1120] rounded-xl text-sm font-bold transition-all disabled:opacity-50 shadow-lg shadow-brand-green/20 hover:shadow-brand-green/30 flex items-center gap-2">
                    {actionLoading === "create" ? (
                      <><svg className="w-4 h-4 animate-spin" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" /><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" /></svg> Creating…</>
                    ) : (
                      <><svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4"><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg> Create Member</>
                    )}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
