"use client";

import React, { useState, useEffect } from "react";
import AdminHeader from "@/components/admin/AdminHeader";
import StatCard from "@/components/admin/StatCard";
import CoachModal from "@/components/admin/CoachModal";
import ConfirmModal from "@/components/admin/ConfirmModal";
import { useRouter } from "next/navigation";
import { useAuthStore } from "@/lib/stores/authStore";
import { 
  getAdminCoachesApi, 
  createAdminCoachApi, 
  updateAdminCoachApi, 
  deleteAdminCoachApi,
  CoachProfile 
} from "@/lib/api";
import { getCapacityColor } from "@/lib/utils";

export default function CoachesPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  
  const [coaches, setCoaches] = useState<CoachProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const router = useRouter();
  
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<"all" | "active" | "inactive" | "available">("all");
  
  const [contextMenu, setContextMenu] = useState<{ mouseX: number; mouseY: number; coach: CoachProfile } | null>(null);
  
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingCoach, setEditingCoach] = useState<CoachProfile | null>(null);

  const [isConfirmOpen, setIsConfirmOpen] = useState(false);
  const [coachToToggle, setCoachToToggle] = useState<{id: string, is_active: boolean} | null>(null);

  const fetchCoaches = async () => {
    if (!accessToken) return;
    try {
      setLoading(true);
      const data = await getAdminCoachesApi(accessToken);
      setCoaches(data);
      setError("");
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Failed to load coaches");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchCoaches();
  }, [accessToken]);

  useEffect(() => {
    const handleGlobalClick = () => setContextMenu(null);
    window.addEventListener("click", handleGlobalClick);
    return () => window.removeEventListener("click", handleGlobalClick);
  }, []);

  const handleOpenCreate = () => {
    setEditingCoach(null);
    setIsModalOpen(true);
  };

  const handleOpenEdit = (coach: CoachProfile) => {
    setEditingCoach(coach);
    setIsModalOpen(true);
  };

  const handleSaveModal = async (payload: any) => {
    if (!accessToken) return {} as any;
    let result;
    if (editingCoach) {
      result = await updateAdminCoachApi(editingCoach.id, payload, accessToken);
    } else {
      result = await createAdminCoachApi(payload, accessToken);
    }
    await fetchCoaches();
    return result;
  };

  const handleToggleActive = (id: string, currentStatus: boolean) => {
    setCoachToToggle({ id, is_active: currentStatus });
    setIsConfirmOpen(true);
  };

  const confirmToggleStatus = async () => {
    if (!accessToken || !coachToToggle) return;
    try {
      if (coachToToggle.is_active) {
        await deleteAdminCoachApi(coachToToggle.id, accessToken);
      } else {
        await updateAdminCoachApi(coachToToggle.id, { is_active: true }, accessToken);
      }
      await fetchCoaches();
    } catch (err: any) {
      setError(err?.data?.error || err?.message || `Failed to ${coachToToggle.is_active ? 'deactivate' : 'activate'} coach`);
    } finally {
      setIsConfirmOpen(false);
      setCoachToToggle(null);
    }
  };

  const activeCoaches = coaches.filter(c => c.is_active);
  const availableCoaches = activeCoaches.filter(c => c.is_available);
  const systemCapacity = coaches.length > 0 ? Math.round((availableCoaches.length / coaches.length) * 100) : 0;

  const filteredCoaches = coaches.filter(c => {
    // 1. Status Filter
    if (statusFilter === "active" && !c.is_active) return false;
    if (statusFilter === "inactive" && c.is_active) return false;
    if (statusFilter === "available" && !c.is_available) return false;
    
    // 2. Search Query Filter
    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      const fullName = `${c.first_name} ${c.last_name}`.toLowerCase();
      const email = (c.email || "").toLowerCase();
      const specialties = (c.specialities || "").toLowerCase();
      
      if (!fullName.includes(query) && !email.includes(query) && !specialties.includes(query)) {
        return false;
      }
    }
    
    return true;
  });

  return (
    <>
      <AdminHeader 
        searchPlaceholder="Search coaches, specialties, or emails..." 
        searchQuery={searchQuery}
        onSearchChange={setSearchQuery}
      />

      <div className="p-6 md:p-8 space-y-6 animate-fade-in-up">
        <p className="text-[10px] font-bold tracking-[0.2em] text-brand-green uppercase">Staff Directory</p>

        <div className="flex items-start justify-between">
          <h1 className="text-3xl font-black text-white">Coach Management</h1>
          <button 
            onClick={handleOpenCreate}
            className="flex items-center gap-2 px-5 py-2.5 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-bold transition-all duration-300 hover:shadow-lg hover:shadow-brand-green/20"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
              <path strokeLinecap="round" strokeLinejoin="round" d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z" />
            </svg>
            ADD NEW COACH
          </button>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <StatCard
            label="Total Roster"
            value={coaches.length.toString()}
            subtitle={`+${coaches.filter(c => new Date(c.created_at).getMonth() === new Date().getMonth()).length} this month`}
            change=""
            extra={
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 text-brand-green">
                <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18L9 11.25l4.306 4.307a11.95 11.95 0 015.814-5.519l2.74-1.22m0 0l-5.94-2.28m5.94 2.28l-2.28 5.941" />
              </svg>
            }
            onClick={() => setStatusFilter("all")}
            isActive={statusFilter === "all"}
          />
          <StatCard
            label="Active Duty"
            value={activeCoaches.length.toString()}
            extra={
              <div className="w-20 h-1.5 bg-white/5 rounded-full overflow-hidden">
                <div className="h-full w-[88%] bg-brand-green rounded-full" />
              </div>
            }
            onClick={() => setStatusFilter("active")}
            isActive={statusFilter === "active"}
          />
          <StatCard
            label="System Capacity"
            value={`${systemCapacity}%`}
            subtitle={`${availableCoaches.length} of ${coaches.length} coaches available`}
            valueColor=""
            valueStyle={{ color: getCapacityColor(systemCapacity) }}
            extra={
              <div className="flex gap-0.5 items-end h-8">
                {[...Array(5)].map((_, i) => {
                  const barHeight = Math.min(100, (systemCapacity / 100) * 100 + (i * 5));
                  return (
                    <div 
                      key={i} 
                      className="w-2 rounded-t-sm transition-all duration-500" 
                      style={{ 
                        height: `${barHeight}%`,
                        backgroundColor: getCapacityColor(systemCapacity),
                        opacity: 0.6 + (i * 0.1)
                      }} 
                    />
                  );
                })}
              </div>
            }
            onClick={() => setStatusFilter("available")}
            isActive={statusFilter === "available"}
          />
        </div>

        {error && (
          <div className="p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm font-medium">
            Error: {error}
          </div>
        )}

        <div className="bg-[#111827]/80 border border-white/5 rounded-2xl">
          <div className="px-6 py-4 flex flex-col md:flex-row md:items-center justify-between border-b border-white/5 gap-4">
            <div className="flex items-center gap-3">
              <h2 className="text-base font-bold text-white">Coach Roster</h2>
              <span className="text-[10px] font-bold tracking-wider text-text-muted/50 bg-white/5 px-2 py-1 rounded-md">{filteredCoaches.length} TOTAL</span>
            </div>
            <div className="flex items-center bg-white/5 rounded-lg p-1">
              <button 
                onClick={() => setStatusFilter("all")} 
                className={`px-3 py-1.5 text-xs font-bold rounded-md transition-colors ${statusFilter === "all" ? "bg-white/10 text-white" : "text-text-muted hover:text-white"}`}
              >
                All
              </button>
              <button 
                onClick={() => setStatusFilter("active")} 
                className={`px-3 py-1.5 text-xs font-bold rounded-md transition-colors ${statusFilter === "active" ? "bg-brand-green/20 text-brand-green" : "text-text-muted hover:text-white"}`}
              >
                Active
              </button>
              <button 
                onClick={() => setStatusFilter("inactive")} 
                className={`px-3 py-1.5 text-xs font-bold rounded-md transition-colors ${statusFilter === "inactive" ? "bg-red-500/20 text-red-400" : "text-text-muted hover:text-white"}`}
              >
                Inactive
              </button>
            </div>
          </div>

          <div className="overflow-x-auto min-h-[300px]">
             {loading ? (
                <div className="p-10 flex justify-center items-center h-[300px]">
                   <div className="w-8 h-8 border-2 border-brand-green border-t-transparent rounded-full animate-spin"></div>
                </div>
             ) : (
                <table className="w-full text-sm">
                  <thead>
                    <tr className="text-[10px] font-bold tracking-[0.15em] text-text-muted/50 uppercase border-b border-white/5">
                      <th className="text-left px-6 py-3">Coach Name</th>
                      <th className="text-left px-6 py-3">Specialities</th>
                      <th className="text-left px-6 py-3">Experience</th>
                      <th className="text-left px-6 py-3">Status</th>
                      <th className="text-right px-6 py-3">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredCoaches.length === 0 ? (
                      <tr>
                        <td colSpan={5} className="px-6 py-8 text-center text-text-muted">No coaches found.</td>
                      </tr>
                    ) : null}
                    {filteredCoaches.map((c) => (
                      <tr 
                        key={c.id} 
                        className={`border-b border-white/5 hover:bg-white/3 transition-colors ${!c.is_active ? 'opacity-50' : ''} cursor-context-menu`}
                        onContextMenu={(e) => {
                          e.preventDefault();
                          setContextMenu({ mouseX: e.clientX, mouseY: e.clientY, coach: c });
                        }}
                      >
                        <td className="px-6 py-4">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-full bg-white/10 border border-white/10 flex items-center justify-center text-white text-xs font-bold overflow-hidden">
                              {c.photo ? (
                                <img src={c.photo} alt={c.first_name} className="w-full h-full object-cover" />
                              ) : (
                                `${c.first_name?.[0] || ""}${c.last_name?.[0] || ""}`.toUpperCase()
                              )}
                            </div>
                            <div>
                              <p className="font-semibold text-white">{c.first_name} {c.last_name}</p>
                              <p className="text-xs text-text-muted">{c.email}</p>
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4 text-text-muted line-clamp-1 max-w-[200px]" title={c.specialities}>{c.specialities || "—"}</td>
                        <td className="px-6 py-4 text-text-muted">{c.years_of_experience} yrs</td>
                        <td className="px-6 py-4">
                          <span className={`flex w-max items-center gap-1.5 text-xs font-bold uppercase tracking-wider ${
                            c.is_active ? "text-brand-green" : "text-red-400"
                          }`}>
                            <span className={`w-1.5 h-1.5 rounded-full ${c.is_active ? "bg-brand-green" : "bg-red-400"}`} />
                            {c.is_active ? "Active" : "Inactive"}
                          </span>
                        </td>
                        <td className="px-6 py-4">
                           <div className="flex justify-end gap-2">
                             <button onClick={() => handleOpenEdit(c)} className="p-2 hover:bg-white/5 rounded-lg text-text-muted hover:text-white transition-colors" title="Edit Coach">
                                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                                  <path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L6.832 19.82a4.5 4.5 0 01-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 011.13-1.897L16.863 4.487zM16.862 4.487L19.5 7.125" />
                                </svg>
                             </button>
                             <button onClick={() => handleToggleActive(c.id, c.is_active)} className={`p-2 hover:bg-white/5 rounded-lg transition-colors ${c.is_active ? "text-text-muted hover:text-red-400" : "text-amber-400 hover:text-brand-green"}`} title={c.is_active ? "Deactivate" : "Activate"}>
                               {c.is_active ? (
                                 <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                                  <path strokeLinecap="round" strokeLinejoin="round" d="M22 10.5h-6m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z" />
                                 </svg>
                               ) : (
                                 <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                                   <path strokeLinecap="round" strokeLinejoin="round" d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z" />
                                 </svg>
                               )}
                             </button>
                           </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
             )}
          </div>
        </div>
      </div>

      <CoachModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
        coach={editingCoach}
        onSave={handleSaveModal}
        accessToken={accessToken ?? undefined}
      />

      <ConfirmModal
        isOpen={isConfirmOpen}
        onClose={() => {
          setIsConfirmOpen(false);
          setCoachToToggle(null);
        }}
        onConfirm={confirmToggleStatus}
        title={coachToToggle?.is_active ? "Deactivate Coach" : "Activate Coach"}
        message={`Are you sure you want to ${coachToToggle?.is_active ? "deactivate" : "activate"} this coach?`}
        confirmText={coachToToggle?.is_active ? "DEACTIVATE" : "ACTIVATE"}
        isDestructive={coachToToggle?.is_active || false}
      />

      {contextMenu && (
        <div 
          className="fixed z-50 bg-[#111827] border border-white/10 rounded-xl shadow-2xl py-1 w-48 animate-fade-in-up"
          style={{ top: contextMenu.mouseY, left: contextMenu.mouseX }}
        >
          <button
            onClick={() => {
              handleOpenEdit(contextMenu.coach);
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
              handleToggleActive(contextMenu.coach.id, contextMenu.coach.is_active);
              setContextMenu(null);
            }}
            className="w-full text-left px-4 py-2 text-sm text-text-muted hover:bg-white/10 hover:text-white transition-colors flex items-center gap-2"
          >
            {contextMenu.coach.is_active ? (
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M22 10.5h-6m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z" />
              </svg>
            ) : (
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z" />
              </svg>
            )}
            {contextMenu.coach.is_active ? "Deactivate" : "Activate"}
          </button>
          <button
            onClick={() => {
              router.push(`/admin/messages?contactId=${contextMenu.coach.id}`);
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
    </>
  );
}
