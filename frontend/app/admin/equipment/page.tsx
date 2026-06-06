"use client";

import React, { useState, useEffect } from "react";
import AdminHeader from "@/components/admin/AdminHeader";
import StatCard from "@/components/admin/StatCard";
import ConfirmModal from "@/components/admin/ConfirmModal";
import AddEquipmentModal from "@/components/admin/AddEquipmentModal";
import { useAuthStore } from "@/lib/stores/authStore";
import { getEquipmentListApi, getEquipmentStatsApi, getRecentMaintenanceLogsApi, createEquipmentApi, deleteEquipmentApi, markEquipmentActiveApi, markEquipmentUnderRepairApi, markEquipmentOutOfOrderApi, Equipment, EquipmentStats, MaintenanceLog } from "@/lib/api";
import { getCapacityColor } from "@/lib/utils";
import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";


/* ── Equipment data ───────────────────────────────────────────────────── */
/* ── Equipment data has been replaced with API calls ─────────────────── */

/* ── Progress Ring ────────────────────────────────────────────────────── */
function HealthGauge({ percentage }: { percentage: number }) {
  const size = 160;
  const strokeWidth = 10;
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const offset = circumference - (percentage / 100) * circumference;

  const color = getCapacityColor(percentage);
  let statusText = "Excellent";
  if (percentage < 10) statusText = "Critical";
  else if (percentage < 40) statusText = "Warning";
  else if (percentage < 75) statusText = "Good";

  return (
    <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
      <svg className="transform -rotate-90" width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={radius} stroke="rgba(255,255,255,0.05)" strokeWidth={strokeWidth} fill="none" />
        <circle
          cx={size / 2} cy={size / 2} r={radius}
          stroke={color} strokeWidth={strokeWidth} fill="none"
          strokeLinecap="round"
          strokeDasharray={circumference} strokeDashoffset={offset}
          className="transition-all duration-1000 ease-out"
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-4xl font-black text-white" style={{ color }}>{percentage}%</span>
        <span className="text-[10px] font-bold uppercase tracking-widest" style={{ color }}>{statusText}</span>
      </div>
    </div>
  );
}

export default function EquipmentPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const [equipmentList, setEquipmentList] = useState<Equipment[]>([]);
  const [maintenanceLogs, setMaintenanceLogs] = useState<MaintenanceLog[]>([]);
  const [stats, setStats] = useState<EquipmentStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 4;
  const [statusFilter, setStatusFilter] = useState<string | null>(null);
  const [showAddModal, setShowAddModal] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState<Equipment | null>(null);
  const [showExportMenu, setShowExportMenu] = useState(false);
  const [actionDropdown, setActionDropdown] = useState<number | string | null>(null);

  useEffect(() => {
    setCurrentPage(1);
  }, [statusFilter]);

  const filteredEquipment = equipmentList.filter((e) => {
    if (!statusFilter) return true;
    return e.status === statusFilter;
  });

  const fetchEquipment = async () => {
    if (!accessToken) return;
    try {
      setLoading(true);
      const [data, statsData, logsData] = await Promise.all([
        getEquipmentListApi(accessToken),
        getEquipmentStatsApi(accessToken),
        getRecentMaintenanceLogsApi(accessToken),
      ]);
      setEquipmentList(data);
      setStats(statsData);
      setMaintenanceLogs(logsData);
      setError("");
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Failed to load equipment");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchEquipment();
  }, [accessToken]);

  const handleAddEquipment = async (payload: { name: string; category: string; status: string }) => {
    if (!accessToken) return;
    await createEquipmentApi(payload, accessToken);
    await fetchEquipment();
  };

  const handleDeleteEquipment = async () => {
    if (!accessToken || !deleteTarget) return;
    try {
      await deleteEquipmentApi(deleteTarget.id, accessToken);
      setDeleteTarget(null);
      await fetchEquipment();
    } catch (err: any) {
      alert(err?.data?.error || err?.message || "Failed to delete");
    }
  };

  const handleChangeStatus = async (eq: Equipment, newStatus: string) => {
    if (!accessToken) return;
    try {
      if (newStatus === "active") await markEquipmentActiveApi(eq.id, accessToken);
      else if (newStatus === "under_repair") await markEquipmentUnderRepairApi(eq.id, accessToken);
      else if (newStatus === "out_of_order") await markEquipmentOutOfOrderApi(eq.id, accessToken);
      setActionDropdown(null);
      await fetchEquipment();
    } catch (err: any) {
      alert(err?.data?.detail || err?.data?.error || err?.message || "Failed to update status");
    }
  };

  const handleExportPDF = () => {
    const doc = new jsPDF();
    doc.text("Equipment Inventory Report", 14, 15);
    const tableData = equipmentList.map(e => [e.name, e.category || "General", e.status_display || e.status, e.last_maintenance_date || "N/A"]);
    autoTable(doc, { head: [["Name", "Category", "Status", "Last Maintenance"]], body: tableData, startY: 20 });
    doc.save("fittech_equipment_report.pdf");
  };

  const handleExportCSV = () => {
    const headers = ["Name", "Category", "Status", "Last Maintenance"];
    const rows = equipmentList.map(e => [e.name, e.category || "General", e.status_display || e.status, e.last_maintenance_date || "N/A"]);
    const csv = [headers.join(","), ...rows.map(r => r.map(x => `"${x}"`).join(","))].join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const link = document.createElement("a"); link.href = URL.createObjectURL(blob); link.download = "fittech_equipment_report.csv"; document.body.appendChild(link); link.click(); document.body.removeChild(link);
  };

  const handleExportJSON = () => {
    const blob = new Blob([JSON.stringify(equipmentList, null, 2)], { type: "application/json" });
    const link = document.createElement("a"); link.href = URL.createObjectURL(blob); link.download = "fittech_equipment_report.json"; document.body.appendChild(link); link.click(); document.body.removeChild(link);
  };

  const handleExportXML = () => {
    let xml = '<?xml version="1.0" encoding="UTF-8"?>\n<equipment_list>\n';
    equipmentList.forEach(e => {
      xml += `  <equipment>\n    <id>${e.id}</id>\n    <name>${(e.name || "").replace(/&/g, "&amp;")}</name>\n    <category>${(e.category || "General").replace(/&/g, "&amp;")}</category>\n    <status>${e.status}</status>\n    <last_maintenance>${e.last_maintenance_date || "N/A"}</last_maintenance>\n  </equipment>\n`;
    });
    xml += "</equipment_list>";
    const blob = new Blob([xml], { type: "application/xml" });
    const link = document.createElement("a"); link.href = URL.createObjectURL(blob); link.download = "fittech_equipment_report.xml"; document.body.appendChild(link); link.click(); document.body.removeChild(link);
  };

  return (
    <>
      <AdminHeader searchPlaceholder="Search inventory ID, serial, or name..." actionLabel="Add Entry" />

      <div className="p-6 md:p-8 space-y-6 animate-fade-in-up">
        {/* Section Label */}
        <p className="text-[10px] font-bold tracking-[0.2em] text-brand-green uppercase">Management Dashboard</p>

        {/* Page Title */}
        <div className="flex items-start justify-between">
          <h1 className="text-3xl font-black text-white">Equipment Inventory</h1>
          <div className="flex items-center gap-3">
            {/* Export As */}
            <div className="relative">
              <button onClick={() => setShowExportMenu(!showExportMenu)} className="flex items-center gap-2 px-4 py-2.5 border border-white/10 hover:border-white/20 text-white rounded-xl text-sm font-bold transition-all duration-300 hover:bg-white/5">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4"><path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" /></svg>
                Export As
              </button>
              {showExportMenu && (
                <>
                  <div className="fixed inset-0 z-40" onClick={() => setShowExportMenu(false)} />
                  <div className="absolute right-0 mt-2 w-32 bg-[#1a2332] border border-white/10 rounded-xl shadow-xl overflow-hidden z-50 animate-fade-in-up">
                    <button onClick={() => { handleExportJSON(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">JSON</button>
                    <button onClick={() => { handleExportXML(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">XML</button>
                    <button onClick={() => { handleExportCSV(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">CSV</button>
                    <button onClick={() => { handleExportPDF(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">PDF</button>
                  </div>
                </>
              )}
            </div>
            <button onClick={() => setShowAddModal(true)} className="flex items-center gap-2 px-5 py-2.5 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-bold transition-all duration-300 hover:shadow-lg hover:shadow-brand-green/20">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4"><path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg>
              Add New Equipment
            </button>
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <StatCard
            label="Total Units"
            value={String(stats?.total ?? "–")}
            subtitle="All registered equipment"
            icon={
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5 text-brand-green">
                <path strokeLinecap="round" strokeLinejoin="round" d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z" />
              </svg>
            }
            onClick={() => setStatusFilter(null)}
            isActive={statusFilter === null}
          />
          <StatCard
            label="Active"
            value={String(stats?.active ?? "–")}
            subtitle="● Live tracking enabled"
            extra={<span className="text-brand-green text-lg font-black">●</span>}
            valueColor="text-brand-green"
            onClick={() => setStatusFilter("active")}
            isActive={statusFilter === "active"}
          />
          <StatCard
            label="Out of Order"
            value={stats?.out_of_order !== undefined ? String(stats.out_of_order).padStart(2, '0') : "–"}
            subtitle={<span className="text-red-500">Priority: High</span>}
            valueColor="text-red-500"
            onClick={() => setStatusFilter("out_of_order")}
            isActive={statusFilter === "out_of_order"}
          />
          <StatCard
            label="Under Maintenance"
            value={stats?.under_repair !== undefined ? String(stats.under_repair).padStart(2, '0') : "–"}
            subtitle={
              <span className="flex items-center gap-1">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-3 h-3"><path strokeLinecap="round" strokeLinejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                Next 48 hours
              </span>
            }
            valueColor="text-amber-500"
            onClick={() => setStatusFilter("under_repair")}
            isActive={statusFilter === "under_repair"}
          />
        </div>

        {/* Equipment Directory Table */}
        <div className="bg-[#111827]/80 border border-white/5 rounded-2xl">
          <div className="px-6 py-4 flex items-center justify-between border-b border-white/5">
            <h2 className="text-base font-bold text-white uppercase tracking-wider">Equipment Directory</h2>
            <div className="flex items-center gap-2">
              <button className="p-2 rounded-lg hover:bg-white/5 text-text-muted/60 hover:text-white transition-colors">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 6h9.75M10.5 6a1.5 1.5 0 11-3 0m3 0a1.5 1.5 0 10-3 0M3.75 6H7.5m3 12h9.75m-9.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-3.75 0H7.5m9-6h3.75m-3.75 0a1.5 1.5 0 01-3 0m3 0a1.5 1.5 0 00-3 0m-9.75 0h9.75" />
                </svg>
              </button>
              <button className="p-2 rounded-lg hover:bg-white/5 text-text-muted/60 hover:text-white transition-colors">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
                </svg>
              </button>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-[10px] font-bold tracking-[0.15em] text-text-muted/50 uppercase border-b border-white/5">
                  <th className="text-left px-6 py-3">Item Name</th>
                  <th className="text-left px-6 py-3">Category</th>
                  <th className="text-left px-6 py-3">Last Maintenance</th>
                  <th className="text-left px-6 py-3">Status</th>
                  <th className="text-right px-6 py-3">Actions</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={5} className="px-6 py-8 text-center text-text-muted">Loading equipment...</td>
                  </tr>
                ) : filteredEquipment.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="px-6 py-8 text-center text-text-muted">No equipment found.</td>
                  </tr>
                ) : (
                  filteredEquipment.slice((currentPage - 1) * itemsPerPage, currentPage * itemsPerPage).map((e) => (
                    <tr key={e.id} className="border-b border-white/5 hover:bg-white/3 transition-colors">
                      <td className="px-6 py-4">
                        <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-lg bg-white/5 flex items-center justify-center text-text-muted/40">
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                              <path strokeLinecap="round" strokeLinejoin="round" d="M11.42 15.17l-5.1-5.1a2.121 2.121 0 113-3l5.1 5.1m0 0l5.1 5.1a2.121 2.121 0 01-3 3l-5.1-5.1" />
                            </svg>
                          </div>
                          <div>
                            <p className="font-semibold text-white">{e.name}</p>
                            <p className="text-[10px] text-text-muted/50">ID: {e.id}</p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-4 text-text-muted text-xs uppercase tracking-wider">{e.category || "General"}</td>
                      <td className="px-6 py-4 text-text-muted">{e.last_maintenance_date || "N/A"}</td>
                      <td className="px-6 py-4">
                        <span className={`text-[10px] font-bold uppercase tracking-wider ${e.status === 'active' ? 'text-brand-green' : e.status === 'under_repair' ? 'text-amber-400' : 'text-red-400'}`}>
                          {e.status_display || e.status}
                        </span>
                      </td>
                      <td className="px-6 py-4 text-right">
                        <div className="relative inline-block">
                          <button onClick={() => setActionDropdown(actionDropdown === e.id ? null : e.id)} className="p-2 rounded-lg hover:bg-white/10 text-text-muted hover:text-white transition-colors">
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4"><path strokeLinecap="round" strokeLinejoin="round" d="M6.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM12.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0zM18.75 12a.75.75 0 11-1.5 0 .75.75 0 011.5 0z" /></svg>
                          </button>
                          {actionDropdown === e.id && (
                            <>
                              <div className="fixed inset-0 z-40" onClick={() => setActionDropdown(null)} />
                              <div className="absolute right-0 mt-1 w-44 bg-[#1a2332] border border-white/10 rounded-xl shadow-xl overflow-hidden z-50 animate-fade-in-up">
                                <p className="px-4 py-2 text-[9px] font-bold text-text-muted/50 uppercase tracking-widest border-b border-white/5">Change Status</p>
                                {e.status !== "active" && (
                                  <button onClick={() => handleChangeStatus(e, "active")} className="w-full text-left px-4 py-2 text-xs font-bold text-brand-green hover:bg-white/10 transition-colors flex items-center gap-2">
                                    <span className="w-1.5 h-1.5 rounded-full bg-brand-green" /> Set Active
                                  </button>
                                )}
                                {e.status !== "under_repair" && (
                                  <button onClick={() => handleChangeStatus(e, "under_repair")} className="w-full text-left px-4 py-2 text-xs font-bold text-amber-400 hover:bg-white/10 transition-colors flex items-center gap-2">
                                    <span className="w-1.5 h-1.5 rounded-full bg-amber-400" /> Under Repair
                                  </button>
                                )}
                                {e.status !== "out_of_order" && (
                                  <button onClick={() => handleChangeStatus(e, "out_of_order")} className="w-full text-left px-4 py-2 text-xs font-bold text-red-400 hover:bg-white/10 transition-colors flex items-center gap-2">
                                    <span className="w-1.5 h-1.5 rounded-full bg-red-400" /> Out of Order
                                  </button>
                                )}
                                <div className="border-t border-white/5" />
                                <button onClick={() => { setActionDropdown(null); setDeleteTarget(e); }} className="w-full text-left px-4 py-2 text-xs font-bold text-red-400 hover:bg-red-500/10 transition-colors flex items-center gap-2">
                                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-3.5 h-3.5"><path strokeLinecap="round" strokeLinejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" /></svg>
                                  Remove
                                </button>
                              </div>
                            </>
                          )}
                        </div>
                      </td>
                    </tr>
                  )))}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="px-6 py-4 flex items-center justify-between border-t border-white/5">
            <span className="text-xs text-text-muted/50">Showing {filteredEquipment.length > 0 ? (currentPage - 1) * itemsPerPage + 1 : 0}-{Math.min(currentPage * itemsPerPage, filteredEquipment.length)} of {filteredEquipment.length} units</span>
            <div className="flex items-center gap-1">
              <button 
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="p-2 rounded-lg text-text-muted hover:text-white transition-colors disabled:opacity-50"
              >
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
                </svg>
              </button>
              {Array.from({ length: Math.max(1, Math.ceil(filteredEquipment.length / itemsPerPage)) }, (_, i) => i + 1).map((p) => (
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
                onClick={() => setCurrentPage(p => Math.min(Math.max(1, Math.ceil(filteredEquipment.length / itemsPerPage)), p + 1))}
                disabled={currentPage === Math.max(1, Math.ceil(filteredEquipment.length / itemsPerPage))}
                className="p-2 rounded-lg text-text-muted hover:text-white transition-colors disabled:opacity-50"
              >
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
                </svg>
              </button>
            </div>
          </div>
        </div>

        {/* Bottom Row: Maintenance Log + Asset Health */}
        <div className="grid grid-cols-1 lg:grid-cols-[1fr_340px] gap-4">
          {/* Recent Maintenance Log */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
            <div className="flex items-center gap-2 mb-5">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5 text-text-muted/60">
                <path strokeLinecap="round" strokeLinejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182" />
              </svg>
              <h2 className="text-sm font-bold text-white uppercase tracking-wider">Recent Maintenance Log</h2>
            </div>
            <div className="space-y-4">
              {maintenanceLogs.map((log) => {
                const partsText = log.parts_cost ? `$${log.parts_cost}` : "N/A";
                const d = new Date(log.date);
                const monthName = d.toLocaleString('default', { month: 'short' }).toUpperCase();
                const dayNum = String(d.getDate()).padStart(2, '0');
                const statusColor = log.status === "COMPLETED" ? "text-brand-green bg-brand-green/10" : "text-amber-400 bg-amber-500/10";
                
                return (
                  <div key={log.id} className="flex items-start gap-4 py-3 border-b border-white/5 last:border-0">
                    <div className="text-center flex-shrink-0">
                      <p className="text-[10px] font-bold text-text-muted/50 uppercase">{monthName}</p>
                      <p className="text-2xl font-black text-white">{dayNum}</p>
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm font-semibold text-white">{log.title}</p>
                      <p className="text-xs text-text-muted mt-0.5">Technician: {log.technician} • Parts: {partsText}</p>
                    </div>
                    <span className={`text-[10px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-md ${statusColor}`}>
                      {log.status}
                    </span>
                  </div>
                );
              })}
            </div>
            <button className="text-xs font-bold text-brand-green uppercase tracking-wider mt-4 hover:text-brand-green-light transition-colors">
              View Full Maintenance Archive
            </button>
          </div>

          {/* Asset Health Score */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6 flex flex-col items-center">
            <h2 className="text-sm font-bold text-white uppercase tracking-wider self-start mb-6">Asset Health Score</h2>
            <HealthGauge percentage={stats?.total ? Math.round(((stats.active || 0) / stats.total) * 100) : 100} />
            <div className="w-full mt-6 space-y-3">
              <div className="flex items-center justify-between text-sm">
                <span className="text-text-muted">Out of Order</span>
                <span className="font-bold text-white">{stats?.total ? Math.round(((stats.out_of_order || 0) / stats.total) * 100) : 0}%</span>
              </div>
              <div>
                <div className="flex items-center justify-between text-sm mb-1.5">
                  <span className="text-text-muted">Currently in Repair</span>
                  <span className="font-bold text-white">{stats?.total ? Math.round(((stats.under_repair || 0) / stats.total) * 100) : 0}%</span>
                </div>
                <div className="w-full h-1.5 bg-white/5 rounded-full overflow-hidden">
                  <div className="h-full bg-blue-500 rounded-full" style={{ width: `${stats?.total ? Math.round(((stats.under_repair || 0) / stats.total) * 100) : 0}%` }} />
                </div>
              </div>
            </div>
            <button onClick={handleExportPDF} className="w-full mt-6 py-3 text-center text-sm font-bold text-white border border-white/10 rounded-xl hover:bg-white/5 transition-all duration-300 uppercase tracking-wider">
              Download Report
            </button>
          </div>
        </div>
      </div>

      {/* Add Equipment Modal */}
      <AddEquipmentModal isOpen={showAddModal} onClose={() => setShowAddModal(false)} onSave={handleAddEquipment} />

      {/* Delete Confirm Modal */}
      <ConfirmModal
        isOpen={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        onConfirm={handleDeleteEquipment}
        title="Remove Equipment"
        message={`Are you sure you want to permanently remove "${deleteTarget?.name || "this equipment"}"? This action cannot be undone.`}
        confirmText="REMOVE"
        isDestructive
      />
    </>
  );
}
