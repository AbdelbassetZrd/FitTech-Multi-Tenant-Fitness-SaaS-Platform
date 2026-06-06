"use client";

import React, { useState, useEffect, useMemo } from "react";
import Link from "next/link";
import AdminHeader from "@/components/admin/AdminHeader";
import StatCard from "@/components/admin/StatCard";
import CourseModal from "@/components/admin/CourseModal";
import ConfirmModal from "@/components/admin/ConfirmModal";
import { useAuthStore } from "@/lib/stores/authStore";
import {
  getAdminCoursesApi,
  getAdminCoachesApi,
  createAdminCourseApi,
  updateAdminCourseApi,
  deleteAdminCourseApi,
  Course,
  CoachProfile,
} from "@/lib/api";

/* ── Helper ─────────────────────────────────────────────────────────────── */

// helper functions removed — this page focuses on courses now

/* ── Page ────────────────────────────────────────────────────────────────── */

export default function SessionsPage() {
  const accessToken = useAuthStore((s) => s.accessToken);

  const [courses, setCourses] = useState<Course[]>([]);
  const [coaches, setCoaches] = useState<CoachProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  /* modal state */
  const [showModal, setShowModal] = useState(false);
  const [editCourse, setEditCourse] = useState<Course | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Course | null>(null);

  /* filter / pagination */
  const [filterStatus, setFilterStatus] = useState<string>("all");
  const [currentPage, setCurrentPage] = useState(1);
  const perPage = 6;

  /* ── Fetch ──────────────────────────────────────────────────────────── */

  const fetchAll = async () => {
    if (!accessToken) return;
    try {
      setLoading(true);
      const [courseData, coachData] = await Promise.all([
        getAdminCoursesApi(accessToken),
        getAdminCoachesApi(accessToken),
      ]);
      // deduplicate courses by composite key to avoid duplicate appearance
      try {
        const map: Record<string, Course> = {};
        (courseData || []).forEach((c) => {
          const key = `${c.name || ''}|${c.day || ''}|${c.time || ''}|${c.coach || c.coach_name || ''}`;
          if (!map[key]) map[key] = c;
        });
        setCourses(Object.values(map));
      } catch (e) {
        setCourses(courseData);
      }
      setCoaches(coachData);
      setError("");
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Failed to load courses");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAll();
  }, [accessToken]);

  /* ── Derived stats ──────────────────────────────────────────────────── */

  const today = new Date().toISOString().split("T")[0];

  const totalCourses = courses.length;
  const totalCapacity = useMemo(() => courses.reduce((s, c) => s + (c.max_members || 0), 0), [courses]);

  /* ── Filtered list ──────────────────────────────────────────────────── */

  const filtered = useMemo(() => courses, [courses]);
  const totalPages = Math.max(1, Math.ceil(filtered.length / perPage));
  const paginated = filtered.slice((currentPage - 1) * perPage, currentPage * perPage);

  /* ── Lookup helpers ─────────────────────────────────────────────────── */

  const courseMap = useMemo(() => {
    const m: Record<number, Course> = {};
    courses.forEach((c) => (m[c.id] = c));
    return m;
  }, [courses]);

  /* ── Handlers ───────────────────────────────────────────────────────── */

  const handleCreate = async (payload: any) => {
    if (!accessToken) return;
    try {
      // Support creating the same course on multiple days: payload.days = ['MON','WED']
      if (Array.isArray(payload.days) && payload.days.length > 0) {
        await Promise.all(payload.days.map((d: string) => {
          const p = { ...payload, day: d };
          delete p.days;
          return createAdminCourseApi(p, accessToken);
        }));
      } else {
        await createAdminCourseApi(payload, accessToken);
      }
    } finally {
      await fetchAll();
    }
  };

  const handleEdit = async (payload: any) => {
    if (!accessToken || !editCourse) return;
    await updateAdminCourseApi(editCourse.id, payload, accessToken);
    await fetchAll();
  };

  const handleDelete = async () => {
    if (!accessToken || !deleteTarget) return;
    try {
      await deleteAdminCourseApi(deleteTarget.id, accessToken);
      setDeleteTarget(null);
      await fetchAll();
    } catch (err: any) {
      alert(err?.data?.error || err?.message || "Delete failed");
    }
  };

  /* ── Category stats (derive from course names) ──────────────────────── */

  const categoryStats = useMemo(() => {
    const cats: Record<string, number> = { Cardio: 0, Strength: 0, HIT: 0 };
    courses.forEach((c) => {
      const name = (c?.name || "").toLowerCase();
      if (name.includes("cardio") || name.includes("crossfit") || name.includes("spinning")) cats["Cardio"]++;
      else if (name.includes("strength") || name.includes("power") || name.includes("lifting")) cats["Strength"]++;
      else cats["HIT"]++;
    });
    return cats;
  }, [courses]);

  /* ── Coach status ───────────────────────────────────────────────────── */

  const coachStats = useMemo(() => {
    const available = coaches.filter((c) => c.is_available && c.is_active).length;
    const onLeave = coaches.filter((c) => !c.is_available || !c.is_active).length;
    return { available, onSession: 0, onLeave };
  }, [coaches]);

  /* ── Render ─────────────────────────────────────────────────────────── */

  return (
    <>
      <AdminHeader
        searchPlaceholder="Search courses, coaches, or members..."
      />

      <div className="p-6 md:p-8 space-y-6 animate-fade-in-up">
        {/* Section label */}
        <p className="text-[10px] font-bold tracking-[0.2em] text-brand-green uppercase">
          Operations
        </p>

        {/* Page Title */}
        <div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
          <div>
            <h1 className="text-3xl font-black text-white">Course Management</h1>
            <p className="text-sm text-text-muted mt-1 max-w-xl">
              Create and manage month-long courses, assign coaches, and define weekly schedule and session counts.
            </p>
          </div>
          <button
            onClick={() => { setEditCourse(null); setShowModal(true); }}
            className="flex items-center gap-2 px-5 py-2.5 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-bold transition-all duration-300 hover:shadow-lg hover:shadow-brand-green/20 shrink-0"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
            </svg>
            ADD NEW COURSE
          </button>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <StatCard
            label="Total Courses"
            value={String(totalCourses)}
            subtitle="Active course offerings"
            icon={<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5 text-brand-green"><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 012.25-2.25h13.5A2.25 2.25 0 0121 7.5v11.25m-18 0A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75m-18 0v-7.5A2.25 2.25 0 015.25 9h13.5A2.25 2.25 0 0121 11.25v7.5" /></svg>}
          />
          <StatCard
            label="Total Capacity"
            value={String(totalCapacity)}
            subtitle="Sum of course capacities"
            icon={<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5 text-blue-400"><path strokeLinecap="round" strokeLinejoin="round" d="M15 19.128a9.38 9.38 0 002.625.372 9.337 9.337 0 004.121-.952 4.125 4.125 0 00-7.533-2.493M15 19.128v-.003c0-1.113-.285-2.16-.786-3.07M15 19.128v.106A12.318 12.318 0 018.624 21c-2.331 0-4.512-.645-6.374-1.766l-.001-.109a6.375 6.375 0 0111.964-3.07M12 6.375a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zm8.25 2.25a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" /></svg>}
          />
          <StatCard
            label="System Health"
            value="Platform Operational"
            subtitle="Real-time sync enabled across centers"
            valueColor="text-brand-green text-lg"
            icon={<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5 text-brand-green"><path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" /></svg>}
          />
        </div>

        {/* Scheduled Sessions Table */}
        <div className="bg-[#111827]/80 border border-white/5 rounded-2xl">
          {/* Table Header */}
          <div className="px-6 py-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 border-b border-white/5">
            <h2 className="text-base font-bold text-white uppercase tracking-wider">Scheduled Sessions</h2>
            <div className="flex items-center gap-3">
              {/* Filter Pills */}
              <div className="flex items-center gap-1 bg-white/5 rounded-lg p-0.5">
                {["all", "active", "completed", "cancelled"].map((f) => (
                  <button
                    key={f}
                    onClick={() => { setFilterStatus(f); setCurrentPage(1); }}
                    className={`px-3 py-1.5 rounded-md text-[10px] font-bold uppercase tracking-wider transition-all ${
                      filterStatus === f
                        ? "bg-brand-green text-[#0B1120]"
                        : "text-text-muted hover:text-white"
                    }`}
                  >
                    {f}
                  </button>
                ))}
              </div>
              {/* Export */}
              <button className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-[10px] font-bold uppercase tracking-wider text-text-muted hover:text-white hover:bg-white/5 transition-colors">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-3.5 h-3.5">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
                </svg>
                Export CSV
              </button>
            </div>
          </div>

          {/* Table */}
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-[10px] font-bold tracking-[0.15em] text-text-muted/50 uppercase border-b border-white/5">
                  <th className="text-left px-6 py-3">Session Name</th>
                  <th className="text-left px-6 py-3">Coach</th>
                  <th className="text-left px-6 py-3">Time Slot</th>
                  <th className="text-left px-6 py-3">Date</th>
                  <th className="text-left px-6 py-3">Status</th>
                  <th className="text-right px-6 py-3">Actions</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={6} className="px-6 py-12 text-center">
                      <div className="flex flex-col items-center gap-3">
                        <div className="w-8 h-8 rounded-full border-2 border-brand-green/20 border-t-brand-green animate-spin" />
                        <p className="text-text-muted text-sm">Loading courses...</p>
                      </div>
                    </td>
                  </tr>
                ) : error ? (
                  <tr>
                    <td colSpan={6} className="px-6 py-12 text-center text-red-400">{error}</td>
                  </tr>
                ) : paginated.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-6 py-12 text-center text-text-muted">No courses found.</td>
                  </tr>
                ) : (
                  paginated.map((c) => {
                    const courseName = c.name || `Course #${c.id}`;
                    const coachName = c.coach_name || "—";
                    const timeStr = c.time || "—";

                    return (
                      <tr key={c.id} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors group">
                        <td className="px-6 py-4">
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-brand-green/20 to-brand-green-dark/10 flex items-center justify-center text-brand-green shrink-0">
                              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M15.362 5.214A8.252 8.252 0 0112 21 8.25 8.25 0 016.038 7.048 8.287 8.287 0 009 9.6a8.983 8.983 0 013.361-6.867 8.21 8.21 0 003 2.48z" />
                              </svg>
                            </div>
                            <div>
                              <p className="font-semibold text-white">{courseName}</p>
                              <p className="text-[10px] text-text-muted/50">
                                {c.max_members ? `Max ${c.max_members}` : "Open"} • {c.number_of_sessions || 0} sessions
                              </p>
                            </div>
                          </div>
                        </td>

                        <td className="px-6 py-4">
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 rounded-full bg-white/10 flex items-center justify-center text-[10px] font-bold text-white shrink-0">
                              {coachName.split(" ").map((n: string) => n[0]).join("").slice(0, 2).toUpperCase()}
                            </div>
                            <span className="text-text-muted text-sm">Coach {coachName.split(" ")[0]}</span>
                          </div>
                        </td>

                        <td className="px-6 py-4 text-text-muted whitespace-nowrap">{c.day} • {timeStr.slice(0,5)}</td>

                        <td className="px-6 py-4">
                          <div>
                            <p className="text-white font-medium">{c.day}</p>
                            <p className="text-[10px] text-text-muted/50">Every week • {c.number_of_sessions || 0} sessions</p>
                          </div>
                        </td>

                        <td className="px-6 py-4">
                          <span className={`text-[10px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-md text-text-muted bg-white/3`}>COURSE</span>
                        </td>

                        <td className="px-6 py-4 text-right">
                          <div className="flex items-center justify-end gap-1 opacity-60 group-hover:opacity-100 transition-opacity">
                            <button
                              onClick={() => { setEditCourse(c); setShowModal(true); }}
                              className="p-2 rounded-lg hover:bg-white/10 text-text-muted hover:text-white transition-colors"
                              title="Edit"
                            >
                              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                              </svg>
                            </button>
                            <button
                              onClick={() => setDeleteTarget(c)}
                              className="p-2 rounded-lg hover:bg-red-500/10 text-text-muted hover:text-red-400 transition-colors"
                              title="Delete"
                            >
                              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                              </svg>
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="px-6 py-4 flex items-center justify-between border-t border-white/5">
            <span className="text-xs text-text-muted/50">
              Showing {filtered.length > 0 ? (currentPage - 1) * perPage + 1 : 0}–{Math.min(currentPage * perPage, filtered.length)} of {filtered.length} sessions
            </span>
            <div className="flex items-center gap-1">
              <button
                onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="p-2 rounded-lg text-text-muted hover:text-white transition-colors disabled:opacity-30"
              >
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
                </svg>
              </button>
              {Array.from({ length: totalPages }, (_, i) => i + 1).map((p) => (
                <button
                  key={p}
                  onClick={() => setCurrentPage(p)}
                  className={`w-8 h-8 rounded-lg text-xs font-bold transition-all ${
                    p === currentPage
                      ? "bg-brand-green text-[#0B1120]"
                      : "text-text-muted hover:bg-white/5 hover:text-white"
                  }`}
                >
                  {p}
                </button>
              ))}
              <button
                onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
                className="p-2 rounded-lg text-text-muted hover:text-white transition-colors disabled:opacity-30"
              >
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
                </svg>
              </button>
            </div>
          </div>
        </div>

        {/* Bottom Row: Category Stats + Staff Status */}
        <div className="grid grid-cols-1 lg:grid-cols-[1fr_380px] gap-4">
          {/* Quick Stats by Category */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
            <div className="flex items-center gap-2 mb-5">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5 text-text-muted/60">
                <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 3v11.25A2.25 2.25 0 006 16.5h2.25M3.75 3h-1.5m1.5 0h16.5m0 0h1.5m-1.5 0v11.25A2.25 2.25 0 0118 16.5h-2.25m-7.5 0h7.5m-7.5 0l-1 3m8.5-3l1 3m0 0l.5 1.5m-.5-1.5h-9.5m0 0l-.5 1.5" />
              </svg>
              <h2 className="text-sm font-bold text-white uppercase tracking-wider">Quick Stats by Category</h2>
            </div>
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
              {Object.entries(categoryStats).map(([cat, count]) => {
                const colors: Record<string, string> = {
                  Cardio: "text-brand-green",
                  Strength: "text-blue-400",
                  HIT: "text-amber-400",
                };
                const barColors: Record<string, string> = {
                  Cardio: "bg-brand-green",
                  Strength: "bg-blue-400",
                  HIT: "bg-amber-400",
                };
                return (
                  <div key={cat} className="bg-white/[0.03] border border-white/5 rounded-xl p-4">
                    <p className="text-[10px] font-bold text-text-muted/50 uppercase tracking-widest">{cat}</p>
                    <div className="flex items-end justify-between mt-2">
                      <span className={`text-3xl font-black ${colors[cat]}`}>{count}</span>
                      <span className="text-[11px] font-semibold text-text-muted flex items-center gap-0.5">
                        {courses.length > 0 ? Math.round((count / courses.length) * 100) : 0}% of total
                      </span>
                    </div>
                    <div className="w-full h-1 bg-white/5 rounded-full mt-3 overflow-hidden">
                      <div
                        className={`h-full rounded-full transition-all duration-1000 ${barColors[cat]}`}
                        style={{ width: `${Math.min(100, (count / Math.max(courses.length, 1)) * 100 + 20)}%` }}
                      />
                    </div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Staff Status */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
            <h2 className="text-sm font-bold text-white uppercase tracking-wider mb-5">Staff Status</h2>
            <div className="space-y-4">
              <div className="flex items-center justify-between py-3 border-b border-white/5">
                <div className="flex items-center gap-3">
                  <span className="w-2.5 h-2.5 rounded-full bg-brand-green shadow-[0_0_8px_rgba(46,204,112,0.5)]" />
                  <span className="text-sm text-text-muted">Available Coaches</span>
                </div>
                <span className="text-lg font-black text-white">{coachStats.available}</span>
              </div>
              <div className="flex items-center justify-between py-3 border-b border-white/5">
                <div className="flex items-center gap-3">
                  <span className="w-2.5 h-2.5 rounded-full bg-blue-400 shadow-[0_0_8px_rgba(96,165,250,0.5)]" />
                  <span className="text-sm text-text-muted">On Session</span>
                </div>
                <span className="text-lg font-black text-white">{coachStats.onSession}</span>
              </div>
              <div className="flex items-center justify-between py-3">
                <div className="flex items-center gap-3">
                  <span className="w-2.5 h-2.5 rounded-full bg-amber-400 shadow-[0_0_8px_rgba(251,191,36,0.5)]" />
                  <span className="text-sm text-text-muted">On Leave</span>
                </div>
                <span className="text-lg font-black text-white">{coachStats.onLeave}</span>
              </div>
            </div>

            <Link 
              href="/admin/coaches"
              className="block w-full mt-6 py-3 text-center text-sm font-bold text-white border border-white/10 rounded-xl hover:bg-white/5 transition-all duration-300 uppercase tracking-wider"
            >
              View Staff Roster
            </Link>
          </div>
        </div>
      </div>

      {/* Course Modal */}
      <CourseModal
        isOpen={showModal}
        course={editCourse}
        onClose={() => { setShowModal(false); setEditCourse(null); }}
        onSave={editCourse ? handleEdit : handleCreate}
      />

      {/* Delete Confirm Modal */}
      <ConfirmModal
        isOpen={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onConfirm={handleDelete}
        title="Delete Course"
        message={`Are you sure you want to delete the course "${deleteTarget?.name || "this course"}"? This action cannot be undone.`}
        confirmText="DELETE"
        isDestructive
      />
    </>
  );
}
