"use client";

import React, { useState, useEffect, useMemo } from "react";
import AdminHeader from "@/components/admin/AdminHeader";
import SubscriptionPlanModal from "@/components/admin/SubscriptionPlanModal";
import ConfirmModal from "@/components/admin/ConfirmModal";
import CreateSubscriptionModal from "@/components/admin/CreateSubscriptionModal";
import ModifySubscriptionModal from "@/components/admin/ModifySubscriptionModal";
import CancelSubscriptionModal from "@/components/admin/CancelSubscriptionModal";
import RevenueEntryModal from "@/components/admin/RevenueEntryModal";
import { useAuthStore } from "@/lib/stores/authStore";
import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import {
  getAdminPlansApi,
  getAdminSubscriptionsApi,
  getAdminPaymentsApi,
  createAdminPlanApi,
  updateAdminPlanApi,
  deleteAdminPlanApi,
  SubscriptionPlan,
  Subscription,
  Payment,
} from "@/lib/api";

/* ── Status helpers ──────────────────────────────────────────────────── */

const PAY_STATUS_BADGE: Record<string, { text: string; cls: string }> = {
  completed: { text: "PAID",    cls: "text-[#2ECC71] bg-[#2ECC71]/10" },
  pending:   { text: "PENDING", cls: "text-amber-400 bg-amber-500/10" },
  failed:    { text: "FAILED",  cls: "text-red-400 bg-red-500/10" },
  refunded:  { text: "REFUNDED",cls: "text-blue-400 bg-blue-500/10" },
};

const SUB_STATUS_BADGE: Record<string, { text: string; cls: string; icon: React.ReactNode }> = {
  active: { text: "PAID", cls: "text-[#2ECC71]", icon: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4">
      <path fillRule="evenodd" d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zm13.36-1.814a.75.75 0 10-1.22-.872l-3.236 4.53L9.53 11.22a.75.75 0 00-1.06 1.06l2.25 2.25a.75.75 0 001.14-.094l3.75-5.25z" clipRule="evenodd" />
    </svg>
  )},
  paused: { text: "PENDING", cls: "text-amber-500", icon: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4">
      <path fillRule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zM12.75 6a.75.75 0 00-1.5 0v6c0 .414.336.75.75.75h4.5a.75.75 0 000-1.5h-3.75V6z" clipRule="evenodd" />
    </svg>
  )},
  expired: { text: "OVERDUE", cls: "text-red-400 bg-red-500/10", icon: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4">
      <path fillRule="evenodd" d="M2.25 12c0-5.385 4.365-9.75 9.75-9.75s9.75 4.365 9.75 9.75-4.365 9.75-9.75 9.75S2.25 17.385 2.25 12zM12 8.25a.75.75 0 01.75.75v3.75a.75.75 0 01-1.5 0V9a.75.75 0 01.75-.75zm0 8.25a.75.75 0 100-1.5.75.75 0 000 1.5z" clipRule="evenodd" />
    </svg>
  )},
  cancelled: { text: "UNPAID", cls: "text-red-400 bg-red-500/10", icon: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-4 h-4">
      <path fillRule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zm-4.28 9.22a.75.75 0 000 1.06h8.56a.75.75 0 000-1.06H7.72z" clipRule="evenodd" />
    </svg>
  )},
};

const getPlanColor = (name: string) => {
  const n = name.toLowerCase();
  if (n.includes('elite')) return 'bg-[#103024] text-[#2ECC71] border-transparent';
  if (n.includes('pro')) return 'bg-[#10243E] text-[#3B82F6] border-transparent';
  return 'bg-[#2A3441] text-gray-300 border-transparent';
}

/* ── Simple bar chart ────────────────────────────────────────────────── */

function RevenueChart({ payments }: { payments: Payment[] }) {
  const last7Days = useMemo(() => {
    const dates = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date();
      d.setDate(d.getDate() - i);
      dates.push(d);
    }
    return dates;
  }, []);

  const days = useMemo(() => {
    return last7Days.map(d => d.toLocaleDateString('en-US', { weekday: 'short' }).toUpperCase());
  }, [last7Days]);

  const dayTotals = useMemo(() => {
    const totals = [0, 0, 0, 0, 0, 0, 0];
    const dayBounds = last7Days.map(d => {
      const start = new Date(d);
      start.setHours(0, 0, 0, 0);
      const end = new Date(d);
      end.setHours(23, 59, 59, 999);
      return { start: start.getTime(), end: end.getTime() };
    });

    payments.forEach((p) => {
      if (p.status === "completed" && p.paid_at) {
        const pTime = new Date(p.paid_at).getTime();
        for (let i = 0; i < 7; i++) {
          if (pTime >= dayBounds[i].start && pTime <= dayBounds[i].end) {
            totals[i] += parseFloat(p.amount) || 0;
            break;
          }
        }
      }
    });
    return totals;
  }, [payments, last7Days]);

  const maxVal = Math.max(...dayTotals, 1);

  return (
    <div className="flex items-end justify-between gap-3 h-48 px-2 mt-6">
      {days.map((day, i) => {
        const height = Math.max(8, (dayTotals[i] / maxVal) * 100);
        const isLatest = i === days.length - 1;
        return (
          <div key={`${day}-${i}`} className="flex flex-col items-center gap-3 flex-1 h-full">
            <div className="w-full h-full flex justify-center items-end relative group">
              <div
                className={`w-full max-w-[48px] rounded-t-sm transition-all duration-700 cursor-pointer ${
                  isLatest ? "bg-[#2ECC71]" : "bg-[#2ECC71]/20 hover:bg-[#2ECC71]/40"
                }`}
                style={{ height: `${height}%` }}
              >
                <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-[#1a2332] text-white text-[10px] font-bold px-2 py-1 rounded-md opacity-0 group-hover:opacity-100 transition-opacity whitespace-nowrap pointer-events-none z-10 shadow-lg">
                  {dayTotals[i].toLocaleString()} DA
                </div>
              </div>
            </div>
            <span className="text-[10px] font-bold text-gray-500 uppercase tracking-wider">{day}</span>
          </div>
        );
      })}
    </div>
  );
}

/* ── Page ─────────────────────────────────────────────────────────────── */

export default function SubscriptionsPage() {
  const accessToken = useAuthStore((s) => s.accessToken);

  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  /* modal state */
  const [showPlanModal, setShowPlanModal] = useState(false);
  const [editPlan, setEditPlan] = useState<SubscriptionPlan | null>(null);
  const [deletePlan, setDeletePlan] = useState<SubscriptionPlan | null>(null);

  /* new subscription modals */
  const [showCreateSubModal, setShowCreateSubModal] = useState(false);
  const [modifySub, setModifySub] = useState<Subscription | null>(null);
  const [cancelSub, setCancelSub] = useState<Subscription | null>(null);
  const [showRevenueEntry, setShowRevenueEntry] = useState(false);

  /* tab & pagination */
  const [activeTab, setActiveTab] = useState<"subscriptions" | "plans">("subscriptions");
  const [currentPage, setCurrentPage] = useState(1);
  const perPage = 5;
  const [showExportMenu, setShowExportMenu] = useState(false);

  /* ── Fetch ──────────────────────────────────────────────────────────── */

  const fetchAll = async () => {
    if (!accessToken) return;
    try {
      setLoading(true);
      const [plansData, subsData, paymentsData] = await Promise.all([
        getAdminPlansApi(accessToken),
        getAdminSubscriptionsApi(accessToken),
        getAdminPaymentsApi(accessToken).catch(() => [] as Payment[]),
      ]);
      setPlans(plansData);
      setSubscriptions(subsData);
      setPayments(paymentsData);
      setError("");
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Failed to load data");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAll();
  }, [accessToken]);

  /* ── Derived stats ──────────────────────────────────────────────────── */

  const totalRevenue = useMemo(() => {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1).getTime();
    return payments
      .filter((p) => p.status === "completed" && p.paid_at && new Date(p.paid_at).getTime() >= startOfMonth)
      .reduce((s, p) => s + (parseFloat(p.amount) || 0), 0);
  }, [payments]);

  const activeSubscriptions = useMemo(
    () => subscriptions.filter((s) => s.status === "active").length,
    [subscriptions],
  );

  const pendingPayments = useMemo(
    () => payments.filter((p) => p.status === "pending").length,
    [payments],
  );

  /* ── Plan allocation ────────────────────────────────────────────────── */

  const planAllocation = useMemo(() => {
    const activeSubs = subscriptions.filter((s) => s.status === "active");
    const total = activeSubs.length || 1;
    const counts: Record<string, number> = {};
    activeSubs.forEach((s) => {
      const planName = s.plan?.name || "Unknown";
      counts[planName] = (counts[planName] || 0) + 1;
    });
    return Object.entries(counts)
      .map(([name, count]) => ({ name, count, percent: Math.round((count / total) * 100) }))
      .sort((a, b) => b.percent - a.percent);
  }, [subscriptions]);

  /* ── Pagination ─────────────────────────────────────────────────────── */

  const visibleSubscriptions = subscriptions.filter((s) => s.status !== "cancelled");

  const totalPages = Math.max(1, Math.ceil(
    (activeTab === "subscriptions" ? visibleSubscriptions.length : plans.length) / perPage
  ));
  const paginatedSubs = visibleSubscriptions.slice((currentPage - 1) * perPage, currentPage * perPage);
  const paginatedPlans = plans.slice((currentPage - 1) * perPage, currentPage * perPage);

  /* ── Handlers ───────────────────────────────────────────────────────── */

  const handleCreatePlan = async (payload: any) => {
    if (!accessToken) return;
    await createAdminPlanApi(payload, accessToken);
    await fetchAll();
  };

  const handleEditPlan = async (payload: any) => {
    if (!accessToken || !editPlan) return;
    await updateAdminPlanApi(editPlan.id, payload, accessToken);
    await fetchAll();
  };

  const handleDeletePlan = async () => {
    if (!accessToken || !deletePlan) return;
    try {
      await deleteAdminPlanApi(deletePlan.id, accessToken);
      setDeletePlan(null);
      await fetchAll();
    } catch (err: any) {
      alert(err?.data?.error || err?.message || "Cannot delete plan");
    }
  };

  const handleExportPDF = () => {
    const doc = new jsPDF();
    const tableData: string[][] = [];

    if (activeTab === "subscriptions") {
      doc.text("Subscriptions Report", 14, 15);
      subscriptions.forEach(sub => {
        tableData.push([
          sub.user_name || "Unknown",
          sub.plan?.name || "Unknown",
          sub.status.toUpperCase(),
          sub.start_date ? new Date(sub.start_date).toLocaleDateString() : "N/A",
          sub.end_date ? new Date(sub.end_date).toLocaleDateString() : "N/A"
        ]);
      });
      autoTable(doc, {
        head: [["Member", "Plan", "Status", "Start Date", "End Date"]],
        body: tableData,
        startY: 20,
      });
    } else {
      doc.text("Subscription Plans Report", 14, 15);
      plans.forEach(plan => {
        tableData.push([
          plan.name,
          `${plan.price} DZD`,
          `${plan.duration_days} days`,
          plan.plan_type.toUpperCase(),
          plan.is_active ? "Active" : "Inactive"
        ]);
      });
      autoTable(doc, {
        head: [["Name", "Price", "Duration", "Tier", "Status"]],
        body: tableData,
        startY: 20,
      });
    }

    doc.save(`fittech_${activeTab}_report.pdf`);
  };

  const handleExportCSV = () => {
    let headers: string[] = [];
    let rows: (string | number)[][] = [];
    
    if (activeTab === "subscriptions") {
      headers = ["Member", "Plan", "Status", "Start Date", "End Date"];
      rows = subscriptions.map(sub => [
        sub.user_name || "Unknown",
        sub.plan?.name || "Unknown",
        sub.status,
        sub.start_date || "",
        sub.end_date || ""
      ]);
    } else {
      headers = ["Name", "Type", "Price", "Duration", "Status"];
      rows = plans.map(plan => [
        plan.name,
        plan.plan_type,
        plan.price,
        plan.duration_days || plan.session_count || "",
        plan.is_active ? "Active" : "Inactive"
      ]);
    }

    const csvContent = [headers.join(","), ...rows.map(r => r.map(x => `"${x}"`).join(","))].join("\n");
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `fittech_${activeTab}_report.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleExportJSON = () => {
    const data = activeTab === "subscriptions" ? subscriptions : plans;
    const jsonContent = JSON.stringify(data, null, 2);
    const blob = new Blob([jsonContent], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `fittech_${activeTab}_report.json`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleExportXML = () => {
    let xmlContent = '<?xml version="1.0" encoding="UTF-8"?>\n';
    
    if (activeTab === "subscriptions") {
      xmlContent += '<subscriptions>\n';
      subscriptions.forEach(sub => {
        xmlContent += `  <subscription>\n`;
        xmlContent += `    <id>${sub.id}</id>\n`;
        xmlContent += `    <member>${sub.user_name ? sub.user_name.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') : 'Unknown'}</member>\n`;
        xmlContent += `    <plan>${sub.plan?.name ? sub.plan.name.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') : 'Unknown'}</plan>\n`;
        xmlContent += `    <status>${sub.status}</status>\n`;
        xmlContent += `    <start_date>${sub.start_date || ''}</start_date>\n`;
        xmlContent += `    <end_date>${sub.end_date || ''}</end_date>\n`;
        xmlContent += `  </subscription>\n`;
      });
      xmlContent += '</subscriptions>';
    } else {
      xmlContent += '<plans>\n';
      plans.forEach(plan => {
        xmlContent += `  <plan>\n`;
        xmlContent += `    <id>${plan.id}</id>\n`;
        xmlContent += `    <name>${plan.name.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}</name>\n`;
        xmlContent += `    <type>${plan.plan_type}</type>\n`;
        xmlContent += `    <price>${plan.price}</price>\n`;
        xmlContent += `    <status>${plan.is_active ? 'Active' : 'Inactive'}</status>\n`;
        xmlContent += `  </plan>\n`;
      });
      xmlContent += '</plans>';
    }

    const blob = new Blob([xmlContent], { type: 'application/xml' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `fittech_${activeTab}_report.xml`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  /* ── Render ─────────────────────────────────────────────────────────── */

  return (
    <>
      <AdminHeader searchPlaceholder="Search members or invoices..." />

      <div className="p-6 md:p-8 space-y-8 animate-fade-in-up bg-[#0B1120]">
        {/* Page Title & Actions */}
        <div className="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
          <div>
            <h1 className="text-3xl font-black text-white">Subscription Management</h1>
            <p className="text-sm text-gray-400 mt-1">
              Monitor revenue streams and member billing cycles.
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-3 shrink-0">
            <div className="relative">
              <button 
                onClick={() => setShowExportMenu(!showExportMenu)}
                className="flex items-center gap-2 px-5 py-2.5 bg-[#334155] hover:bg-[#475569] text-white rounded-lg text-sm font-semibold transition-all shadow-sm"
              >
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
                </svg>
                Export As
              </button>
              {showExportMenu && (
                <>
                  <div className="fixed inset-0 z-40" onClick={() => setShowExportMenu(false)} />
                  <div className="absolute right-0 mt-2 w-32 bg-[#1C2434] border border-white/10 rounded-xl shadow-xl overflow-hidden z-50">
                    <button onClick={() => { handleExportJSON(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">JSON</button>
                    <button onClick={() => { handleExportXML(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">XML</button>
                    <button onClick={() => { handleExportCSV(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">CSV</button>
                    <button onClick={() => { handleExportPDF(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">PDF</button>
                  </div>
                </>
              )}
            </div>

            <button
              onClick={() => { setEditPlan(null); setShowPlanModal(true); }}
              className="flex items-center gap-2 px-4 py-2.5 bg-transparent border border-white/20 hover:border-white/40 text-white rounded-lg text-sm font-semibold transition-all"
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Create Plan
            </button>

            <button
              onClick={() => setShowRevenueEntry(true)}
              className="flex items-center gap-2 px-5 py-2.5 bg-[#2ECC71] hover:bg-[#27AE60] text-[#0B1120] rounded-lg text-sm font-bold transition-all shadow-md hover:shadow-lg hover:shadow-[#2ECC71]/20"
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor" className="w-4 h-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              Create Invoice
            </button>

            <button
              onClick={() => setShowCreateSubModal(true)}
              className="flex items-center gap-2 px-5 py-2.5 bg-[#2ECC71] hover:bg-[#27AE60] text-[#0B1120] rounded-lg text-sm font-bold transition-all shadow-md hover:shadow-lg hover:shadow-[#2ECC71]/20"
            >
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor" className="w-4 h-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
              </svg>
              + Subscription
            </button>
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {/* Total Revenue */}
          <div className="bg-[#1C2434] rounded-2xl p-6 relative overflow-hidden flex flex-col justify-between shadow-lg">
            <div className="relative z-10">
              <h3 className="text-[11px] font-bold text-gray-400 tracking-wider uppercase mb-4">Total Revenue</h3>
              <div className="flex items-baseline gap-3 mb-4">
                <span className="text-4xl font-black text-[#2ECC71]">
                  {totalRevenue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} DA
                </span>
                <span className="text-sm font-bold text-[#2ECC71] flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4 mr-0.5">
                    <path fillRule="evenodd" d="M12 7a1 1 0 110-2h5v5a1 1 0 11-2 0V8.414l-4.293 4.293a1 1 0 01-1.414 0L6 9.414l-3.293 3.293a1 1 0 01-1.414-1.414l4-4a1 1 0 011.414 0L10 10.586l3.293-3.293H12z" clipRule="evenodd" />
                  </svg>
                  12.5%
                </span>
              </div>
              <p className="text-xs text-gray-400 max-w-[200px] leading-relaxed">Current Billing Cycle (DZD equivalent available)</p>
            </div>
            <div className="absolute top-4 right-4 text-white/[0.03] w-24 h-24 pointer-events-none">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V5.903c0-.755-.726-1.295-1.453-1.097A60.05 60.05 0 002.25 5.25m0 13.5L2.25 5.25m0 13.5H15m-12.75 0V5.25m0 0H15M2.25 5.25v13.5m0-13.5h15" />
              </svg>
            </div>
          </div>

          {/* Pending Payments */}
          <div className="bg-[#1C2434] rounded-2xl p-6 relative overflow-hidden flex flex-col justify-between shadow-lg">
            <div className="relative z-10">
              <h3 className="text-[11px] font-bold text-gray-400 tracking-wider uppercase mb-4">Pending Payments</h3>
              <div className="flex items-baseline gap-2 mb-4">
                <span className="text-4xl font-black text-amber-500">{pendingPayments}</span>
                <span className="text-sm font-bold text-amber-500">Invoices</span>
              </div>
              <p className="text-xs text-gray-400">Awaiting settlement</p>
            </div>
            <div className="absolute top-4 right-4 text-white/[0.03] w-24 h-24 pointer-events-none">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" d="M9 12h3.75M9 15h3.75M9 18h3.75m3 .75H18a2.25 2.25 0 002.25-2.25V6.108c0-1.135-.845-2.098-1.976-2.192a48.424 48.424 0 00-1.123-.08m-5.801 0c-.065.21-.1.433-.1.664 0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75 2.25 2.25 0 00-.1-.664m-5.8 0A2.251 2.251 0 0113.5 2.25H15c1.012 0 1.867.668 2.15 1.586m-5.8 0c-.376.023-.75.05-1.124.08C9.095 4.01 8.25 4.973 8.25 6.108V8.25m0 0H4.875c-.621 0-1.125.504-1.125 1.125v11.25c0 .621.504 1.125 1.125 1.125h9.75c.621 0 1.125-.504 1.125-1.125V9.375c0-.621-.504-1.125-1.125-1.125H8.25zM6.75 12h.008v.008H6.75V12zm0 3h.008v.008H6.75V15zm0 3h.008v.008H6.75V18z" />
              </svg>
            </div>
          </div>

          {/* Active Subscriptions */}
          <div className="bg-[#1C2434] rounded-2xl p-6 relative overflow-hidden flex flex-col justify-between shadow-lg">
            <div className="relative z-10">
              <h3 className="text-[11px] font-bold text-gray-400 tracking-wider uppercase mb-4">Active Subscriptions</h3>
              <div className="flex items-center gap-4 mb-4">
                <span className="text-4xl font-black text-blue-400">{activeSubscriptions}</span>
                <div className="flex -space-x-2">
                  <div className="w-8 h-8 rounded-full border-2 border-[#1C2434] bg-gray-600 flex items-center justify-center text-[10px]">A</div>
                  <div className="w-8 h-8 rounded-full border-2 border-[#1C2434] bg-gray-500 flex items-center justify-center text-[10px]">B</div>
                  <div className="w-8 h-8 rounded-full border-2 border-[#1C2434] bg-gray-400 flex items-center justify-center text-[10px]">C</div>
                </div>
              </div>
              <div className="flex items-center gap-4 text-[10px] font-bold text-gray-400 uppercase tracking-wider">
                <div className="flex items-center gap-1.5">
                  <div className="w-2 h-2 rounded-full bg-[#2ECC71]"></div>
                  ELITE: {planAllocation.find(p => p.name.toLowerCase().includes('elite'))?.count || 0}
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="w-2 h-2 rounded-full bg-blue-500"></div>
                  PRO: {planAllocation.find(p => p.name.toLowerCase().includes('pro'))?.count || 0}
                </div>
              </div>
            </div>
            <div className="absolute top-4 right-4 text-white/[0.03] w-24 h-24 pointer-events-none">
               <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                 <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12c0 1.268-.63 2.39-1.593 3.068a3.745 3.745 0 01-1.043 3.296 3.745 3.745 0 01-3.296 1.043A3.745 3.745 0 0112 21c-1.268 0-2.39-.63-3.068-1.593a3.746 3.746 0 01-3.296-1.043 3.745 3.745 0 01-1.043-3.296A3.745 3.745 0 013 12c0-1.268.63-2.39 1.593-3.068a3.745 3.745 0 011.043-3.296 3.746 3.746 0 013.296-1.043A3.746 3.746 0 0112 3c1.268 0 2.39.63 3.068 1.593a3.746 3.746 0 013.296 1.043 3.746 3.746 0 011.043 3.296A3.745 3.745 0 0121 12z" />
               </svg>
            </div>
          </div>
        </div>

        {/* Table */}
        <div className="bg-[#1C2434] rounded-2xl shadow-lg border border-white/5">
          <div className="px-6 py-5 flex items-center justify-between border-b border-white/5">
            <h2 className="text-xs font-bold text-white uppercase tracking-wider">
              {activeTab === "subscriptions" ? "Recent Transactions" : "Subscription Plans"}
            </h2>
            <div className="bg-[#111827] rounded-lg p-1 flex">
              <button
                onClick={() => { setActiveTab("subscriptions"); setCurrentPage(1); }}
                className={`px-4 py-1.5 rounded-md text-xs font-bold transition-all ${
                  activeTab === "subscriptions" ? "bg-[#334155] text-white shadow-sm" : "text-gray-400 hover:text-white"
                }`}
              >
                Transactions
              </button>
              <button
                onClick={() => { setActiveTab("plans"); setCurrentPage(1); }}
                className={`px-4 py-1.5 rounded-md text-xs font-bold transition-all ${
                  activeTab === "plans" ? "bg-[#334155] text-white shadow-sm" : "text-gray-400 hover:text-white"
                }`}
              >
                Plans
              </button>
            </div>
          </div>

          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="text-[10px] font-bold tracking-[0.1em] text-gray-500 uppercase border-b border-white/5">
                  {activeTab === "subscriptions" ? (
                    <>
                      <th className="text-left px-6 py-4">Member Name</th>
                      <th className="text-left px-6 py-4">Subscription Plan</th>
                      <th className="text-left px-6 py-4">Amount</th>
                      <th className="text-left px-6 py-4">Date</th>
                      <th className="text-left px-6 py-4">Status</th>
                      <th className="text-right px-6 py-4">Actions</th>
                    </>
                  ) : (
                    <>
                      <th className="text-left px-6 py-4">Plan Name</th>
                      <th className="text-left px-6 py-4">Type</th>
                      <th className="text-left px-6 py-4">Price</th>
                      <th className="text-left px-6 py-4">Duration</th>
                      <th className="text-left px-6 py-4">Status</th>
                      <th className="text-right px-6 py-4">Actions</th>
                    </>
                  )}
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={6} className="px-6 py-12 text-center">
                      <div className="flex flex-col items-center gap-3">
                        <div className="w-8 h-8 rounded-full border-2 border-[#2ECC71]/20 border-t-[#2ECC71] animate-spin" />
                        <p className="text-gray-400 text-sm">Loading...</p>
                      </div>
                    </td>
                  </tr>
                ) : error ? (
                  <tr>
                    <td colSpan={6} className="px-6 py-12 text-center text-red-400">{error}</td>
                  </tr>
                ) : activeTab === "subscriptions" && paginatedSubs.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-6 py-12 text-center text-gray-500">No subscriptions found.</td>
                  </tr>
                ) : activeTab === "plans" && paginatedPlans.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="px-6 py-12 text-center text-gray-500">No plans found.</td>
                  </tr>
                ) : activeTab === "subscriptions" ? (
                  paginatedSubs.map((sub) => {
                    // Find the latest payment for this subscription
                    const subPayments = payments
                      .filter((p) => p.subscription === sub.id)
                      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
                    const latestPayment = subPayments[0];
                    const payBadge = latestPayment
                      ? (PAY_STATUS_BADGE[latestPayment.status] || { text: latestPayment.status.toUpperCase(), cls: "text-gray-400 bg-white/5" })
                      : (SUB_STATUS_BADGE[sub.status] || SUB_STATUS_BADGE.cancelled);
                    const isUnpaid = latestPayment
                      ? latestPayment.status !== 'completed'
                      : sub.status === 'cancelled' || sub.status === 'expired';
                    const planBadgeCls = getPlanColor(sub.plan?.name || "");

                    return (
                      <tr key={sub.id} className={`border-b border-white/5 transition-colors group ${
                          isUnpaid
                            ? 'bg-red-500/5 hover:bg-red-500/10'
                            : 'hover:bg-white/[0.02]'
                        }`}>
                        <td className="px-6 py-4">
                          <div className="flex items-center gap-3">
                            <div className="w-9 h-9 rounded-full bg-gradient-to-br from-[#2ECC71]/20 to-[#2ECC71]/5 flex items-center justify-center text-[#2ECC71] text-xs font-bold shrink-0">
                              {(sub.user_name || "?").split(" ").map((n) => n[0]).join("").slice(0, 2).toUpperCase()}
                            </div>
                            <div>
                              <p className="font-semibold text-white">{sub.user_name || "Unknown"}</p>
                              <p className="text-[10px] text-gray-500">ID: #FT-{String(sub.id).padStart(4, "0")}</p>
                            </div>
                          </div>
                        </td>
                        <td className="px-6 py-4">
                          <span className={`text-[9px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-full ${planBadgeCls}`}>
                            {sub.plan?.name || "—"}
                          </span>
                        </td>
                        <td className="px-6 py-4 font-bold text-white">
                          {parseFloat(sub.plan?.price || "0").toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} DZD
                        </td>
                        <td className="px-6 py-4 text-gray-400 text-sm">
                          {sub.start_date ? new Date(sub.start_date + "T00:00:00").toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" }) : "—"}
                        </td>
                        <td className="px-6 py-4">
                          <span className={`text-[10px] font-bold uppercase tracking-wider px-2 py-1 rounded-md ${payBadge.cls}`}>
                            {payBadge.text}
                          </span>
                        </td>
                        <td className="px-6 py-4 text-right">
                          <div className="flex items-center justify-end gap-3 opacity-60 group-hover:opacity-100 transition-opacity">
                            <button onClick={() => setModifySub(sub)} className="hover:text-white transition-colors" title="Modify Plan">
                              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 12h16.5m-16.5 3.75h16.5M3.75 19.5h16.5M5.625 4.5h12.75a1.875 1.875 0 011.875 1.875v1.5c0 1.036-.84 1.875-1.875 1.875H5.625a1.875 1.875 0 01-1.875-1.875v-1.5c0-1.036.84-1.875 1.875-1.875z" />
                              </svg>
                            </button>
                            {sub.status === "active" && (
                              <button onClick={() => setCancelSub(sub)} className="hover:text-red-400 transition-colors" title="Cancel Subscription">
                                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4">
                                  <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                                </svg>
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    );
                  })
                ) : (
                  paginatedPlans.map((plan) => {
                    const planBadgeCls = getPlanColor(plan.name);
                    return (
                      <tr key={plan.id} className="border-b border-white/5 hover:bg-white/[0.02] transition-colors group">
                        <td className="px-6 py-4">
                          <p className="font-semibold text-white">{plan.name}</p>
                        </td>
                        <td className="px-6 py-4">
                          <span className={`text-[9px] font-bold uppercase tracking-wider px-2.5 py-1 rounded-full ${planBadgeCls}`}>
                            {plan.plan_type.replace("_", " ")}
                          </span>
                        </td>
                        <td className="px-6 py-4 font-bold text-white">
                          {parseFloat(plan.price).toLocaleString()} DZD
                        </td>
                        <td className="px-6 py-4 text-gray-400 text-sm">
                          {plan.duration_days ? `${plan.duration_days} days` : plan.session_count ? `${plan.session_count} sessions` : "—"}
                        </td>
                        <td className="px-6 py-4">
                          <span className={`text-[10px] font-bold uppercase tracking-wider ${plan.is_active ? 'text-[#2ECC71]' : 'text-gray-500'}`}>
                            {plan.is_active ? "ACTIVE" : "INACTIVE"}
                          </span>
                        </td>
                        <td className="px-6 py-4 text-right">
                          <div className="flex items-center justify-end gap-3 opacity-60 group-hover:opacity-100 transition-opacity">
                            <button onClick={() => { setEditPlan(plan); setShowPlanModal(true); }} className="hover:text-white transition-colors" title="Edit">
                              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
                                <path strokeLinecap="round" strokeLinejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0115.75 21H5.25A2.25 2.25 0 013 18.75V8.25A2.25 2.25 0 015.25 6H10" />
                              </svg>
                            </button>
                            <button onClick={() => setDeletePlan(plan)} className="hover:text-red-400 transition-colors" title="Delete">
                              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
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

          <div className="px-6 py-5 flex items-center justify-between border-t border-white/5">
            <span className="text-xs text-gray-500">
              Showing {(activeTab === "subscriptions" ? subscriptions : plans).length > 0 ? (currentPage - 1) * perPage + 1 : 0} of{" "}
              {(activeTab === "subscriptions" ? subscriptions : plans).length} records
            </span>
            <div className="flex items-center gap-4 text-xs font-bold text-gray-400">
              <button
                onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
                disabled={currentPage === 1}
                className="hover:text-white transition-colors disabled:opacity-30 flex items-center gap-1"
              >
                ‹ Previous
              </button>
              <span className="text-white">
                Page {currentPage} of {totalPages}
              </span>
              <button
                onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
                disabled={currentPage === totalPages}
                className="hover:text-white transition-colors disabled:opacity-30 flex items-center gap-1"
              >
                Next ›
              </button>
            </div>
          </div>
        </div>

        {/* Bottom Row */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 pb-12">
          {/* Revenue Growth */}
          <div className="bg-[#1C2434] rounded-2xl p-6 relative shadow-lg">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xs font-bold text-white uppercase tracking-wider">Revenue Growth</h2>
              <span className="text-[10px] font-bold text-[#2ECC71] bg-[#103024] px-2.5 py-1 rounded-full border border-[#2ECC71]/20">
                +8% vs last month
              </span>
            </div>
            <RevenueChart payments={payments} />
          </div>

          {/* Plan Allocation */}
          <div className="bg-[#1C2434] rounded-2xl p-6 relative shadow-lg flex flex-col justify-between">
            <div>
              <h2 className="text-xs font-bold text-white uppercase tracking-wider mb-8">Plan Allocation</h2>
              <div className="space-y-6">
                {planAllocation.length === 0 ? (
                  <p className="text-gray-500 text-sm">No active subscriptions to analyze.</p>
                ) : (
                  planAllocation.map(({ name, percent }) => {
                    const n = name.toLowerCase();
                    const barColor = n.includes('elite') ? "bg-[#2ECC71]" : n.includes('pro') ? "bg-blue-500" : "bg-gray-400";
                    return (
                      <div key={name}>
                        <div className="flex items-center justify-between mb-2">
                          <span className="text-xs font-semibold text-white">{name}</span>
                          <span className={`text-xs font-bold ${n.includes('elite') ? 'text-[#2ECC71]' : n.includes('pro') ? 'text-blue-500' : 'text-gray-400'}`}>
                            {percent}%
                          </span>
                        </div>
                        <div className="w-full h-2 bg-[#2A3441] rounded-full overflow-hidden">
                          <div
                            className={`h-full rounded-full transition-all duration-1000 ${barColor}`}
                            style={{ width: `${percent}%` }}
                          />
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>
            
            <div className="mt-8 p-4 bg-[#102A20] border border-[#2ECC71]/20 rounded-xl">
               <p className="text-xs text-[#2ECC71] text-center leading-relaxed">
                 "Elite tier conversion has increased by 4% following the new weekend bootcamp program launch."
               </p>
            </div>
          </div>
        </div>
      </div>

      {/* Modals */}
      <SubscriptionPlanModal
        isOpen={showPlanModal}
        plan={editPlan}
        onClose={() => { setShowPlanModal(false); setEditPlan(null); }}
        onSave={editPlan ? handleEditPlan : handleCreatePlan}
      />

      <ConfirmModal
        isOpen={!!deletePlan}
        onClose={() => setDeletePlan(null)}
        onConfirm={handleDeletePlan}
        title="Deactivate Plan"
        message={`Are you sure you want to deactivate "${deletePlan?.name || "this plan"}"? Plans with active subscriptions will be soft-deleted (deactivated).`}
        confirmText="DEACTIVATE"
        isDestructive
      />

      <CreateSubscriptionModal
        isOpen={showCreateSubModal}
        onClose={() => setShowCreateSubModal(false)}
        onSuccess={fetchAll}
      />

      <ModifySubscriptionModal
        isOpen={!!modifySub}
        onClose={() => setModifySub(null)}
        onSuccess={fetchAll}
        subscription={modifySub}
      />

      <CancelSubscriptionModal
        isOpen={!!cancelSub}
        onClose={() => setCancelSub(null)}
        onSuccess={() => {
          if (cancelSub) {
            setSubscriptions((prev) => prev.filter((s) => s.id !== cancelSub.id));
          }
          setCancelSub(null);
          fetchAll();
        }}
        subscription={cancelSub}
      />

      <RevenueEntryModal
        isOpen={showRevenueEntry}
        onClose={() => setShowRevenueEntry(false)}
        onSuccess={fetchAll}
      />
    </>
  );
}
