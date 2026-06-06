"use client";

import React, { useState, useEffect, useMemo } from "react";
import Link from "next/link";
import jsPDF from "jspdf";
import autoTable from "jspdf-autotable";
import AdminHeader from "@/components/admin/AdminHeader";
import StatCard from "@/components/admin/StatCard";
import { useAuthStore } from "@/lib/stores/authStore";
import {
  getAdminMembersApi,
  getAdminSubscriptionsApi,
  getAdminPaymentsApi,
  getAdminSessionsApi,
  User,
  Subscription,
  Payment,
  Session,
} from "@/lib/api";

/* ── Revenue Line Chart (Dynamic) ─────────────────────────────────────── */
function RevenueChart({ payments, timeFilter }: { payments: Payment[], timeFilter: "all" | "30days" }) {
  const width = 600;
  const height = 200;
  const monthNames = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
  
  const now = new Date();
  const data: { label: string; revenue: number; showLabel: boolean }[] = [];

  if (timeFilter === "30days") {
    // Generate daily data for the last 30 days
    for (let i = 29; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i);
      const labelStr = `${d.getDate()} ${monthNames[d.getMonth()]}`;
      const revenue = payments
        .filter((p) => p.status === "completed" && p.paid_at)
        .filter((p) => {
          const pd = new Date(p.paid_at!);
          return pd.getDate() === d.getDate() && pd.getMonth() === d.getMonth() && pd.getFullYear() === d.getFullYear();
        })
        .reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
      data.push({ 
        label: labelStr, 
        revenue, 
        showLabel: i % 5 === 0 || i === 0 || i === 29 
      });
    }
  } else {
    // Generate monthly data for the last 7 months
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const labelStr = monthNames[d.getMonth()];
      const revenue = payments
        .filter((p) => p.status === "completed" && p.paid_at)
        .filter((p) => {
          const pd = new Date(p.paid_at!);
          return pd.getMonth() === d.getMonth() && pd.getFullYear() === d.getFullYear();
        })
        .reduce((sum, p) => sum + (parseFloat(p.amount) || 0), 0);
      data.push({ 
        label: labelStr, 
        revenue,
        showLabel: true
      });
    }
  }

  const maxRev = Math.max(...data.map(d => d.revenue), 100);

  // Map revenue to Y coordinates (inverted because higher Y is lower visually)
  const points = data.map((d, i) => {
    const x = i * (width / (data.length - 1));
    const y = height - (d.revenue / maxRev) * (height - 30); // 30px padding at top
    return { x, y, revenue: d.revenue, label: d.label, showLabel: d.showLabel };
  });

  const pathD = points.length > 0 ? points.reduce((acc, p, i) => {
    if (i === 0) return `M ${p.x} ${p.y}`;
    const prev = points[i - 1];
    const cpx1 = prev.x + (p.x - prev.x) / 3;
    const cpx2 = p.x - (p.x - prev.x) / 3;
    return `${acc} C ${cpx1} ${prev.y}, ${cpx2} ${p.y}, ${p.x} ${p.y}`;
  }, "") : `M 0 ${height} L ${width} ${height}`;

  const areaD = points.length > 0 ? `${pathD} L ${points[points.length - 1].x} ${height} L ${points[0].x} ${height} Z` : "";

  return (
    <div className="relative">
      <svg viewBox={`0 0 ${width} ${height + 30}`} className="w-full h-auto overflow-visible">
        <defs>
          <linearGradient id="areaGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#2ECC70" stopOpacity="0.3" />
            <stop offset="100%" stopColor="#2ECC70" stopOpacity="0.02" />
          </linearGradient>
          <linearGradient id="lineGradient" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="#2ECC70" />
            <stop offset="100%" stopColor="#34D399" />
          </linearGradient>
        </defs>
        {/* Grid lines */}
        {[0, 1, 2, 3, 4].map((i) => (
          <line key={i} x1="0" y1={i * (height / 4)} x2={width} y2={i * (height / 4)} stroke="rgba(255,255,255,0.03)" strokeWidth="1" />
        ))}
        {/* Area fill */}
        {points.length > 0 && <path d={areaD} fill="url(#areaGradient)" />}
        {/* Line */}
        {points.length > 0 && <path d={pathD} fill="none" stroke="url(#lineGradient)" strokeWidth="3" strokeLinecap="round" />}
        {/* Dots */}
        {points.map((p, i) => (
          <g key={i} className="group relative">
            <circle cx={p.x} cy={p.y} r={timeFilter === "30days" ? "2.5" : "4"} fill="#2ECC70" stroke="#111827" strokeWidth="2" className="cursor-pointer hover:r-6 transition-all" />
            <text x={p.x} y={p.y - 15} fill="white" fontSize="12" fontWeight="700" textAnchor="middle" className="opacity-0 group-hover:opacity-100 transition-opacity">
              {p.revenue.toLocaleString()}
            </text>
          </g>
        ))}
        {/* X-axis labels */}
        {points.map((p, i) => (
          p.showLabel && (
            <text key={`label-${i}`} x={p.x} y={height + 22} fill="rgba(148,163,184,0.4)" fontSize="10" fontWeight="700" textAnchor="middle" letterSpacing="0.1em">
              {p.label}
            </text>
          )
        ))}
      </svg>
    </div>
  );
}

/* ── Facility Load Gauge ──────────────────────────────────────────────── */
function FacilityGauge({ percentage }: { percentage: number }) {
  const size = 140;
  const strokeWidth = 8;
  const radius = (size - strokeWidth) / 2;
  const circumference = radius * 2 * Math.PI;
  const offset = circumference - (percentage / 100) * circumference;

  return (
    <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
      <svg className="transform -rotate-90" width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={radius} stroke="rgba(255,255,255,0.05)" strokeWidth={strokeWidth} fill="none" />
        <circle
          cx={size / 2} cy={size / 2} r={radius}
          stroke="#2ECC70" strokeWidth={strokeWidth} fill="none"
          strokeLinecap="round"
          strokeDasharray={circumference} strokeDashoffset={offset}
          className="transition-all duration-1000 ease-out"
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="text-3xl font-black text-white">{percentage}%</span>
        <span className="text-[10px] font-bold text-brand-green uppercase tracking-wider">Load</span>
      </div>
    </div>
  );
}

/* ── Class Popularity Bar ─────────────────────────────────────────────── */
function PopularityBar({ name, percentage, color }: { name: string; percentage: number; color: string }) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between">
        <span className="text-sm font-bold text-white uppercase tracking-wider truncate w-32">{name}</span>
        <span className="text-sm font-bold text-text-muted">{percentage}%</span>
      </div>
      <div className="w-full h-2 bg-white/5 rounded-full overflow-hidden">
        <div className={`h-full ${color} rounded-full transition-all duration-1000`} style={{ width: `${percentage}%` }} />
      </div>
    </div>
  );
}

export default function ReportsPage() {
  const accessToken = useAuthStore((s) => s.accessToken);

  const [members, setMembers] = useState<User[]>([]);
  const [subscriptions, setSubscriptions] = useState<Subscription[]>([]);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [sessions, setSessions] = useState<Session[]>([]);
  const [loading, setLoading] = useState(true);
  const [timeFilter, setTimeFilter] = useState<"all" | "30days">("all");
  const [showExportMenu, setShowExportMenu] = useState(false);

  useEffect(() => {
    if (!accessToken) return;
    const fetchAll = async () => {
      try {
        setLoading(true);
        const [m, s, p, sess] = await Promise.all([
          getAdminMembersApi(accessToken),
          getAdminSubscriptionsApi(accessToken),
          getAdminPaymentsApi(accessToken).catch(() => []),
          getAdminSessionsApi(accessToken),
        ]);
        setMembers(m);
        setSubscriptions(s);
        setPayments(p);
        setSessions(sess);
      } catch {
        // silently handle
      } finally {
        setLoading(false);
      }
    };
    fetchAll();
  }, [accessToken]);

  /* ── Computed Data ────────────────────────────────────────────────────── */
  
  const now = new Date();
  const currentMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

  // Filtered data based on timeFilter
  const filteredPayments = timeFilter === "30days" 
    ? payments.filter(p => new Date(p.created_at) >= thirtyDaysAgo)
    : payments;

  const filteredSubscriptions = timeFilter === "30days"
    ? subscriptions.filter(s => new Date(s.created_at) >= thirtyDaysAgo)
    : subscriptions;

  const filteredMembers = timeFilter === "30days"
    ? members.filter(m => new Date(m.created_at) >= thirtyDaysAgo)
    : members;

  // Revenue
  const completedPayments = filteredPayments.filter((p) => p.status === "completed" && p.paid_at);
  const totalRevenue = completedPayments.reduce((s, p) => s + (parseFloat(p.amount) || 0), 0);
  
  const currentMonRev = completedPayments.filter(p => new Date(p.paid_at!) >= currentMonthStart).reduce((s, p) => s + (parseFloat(p.amount) || 0), 0);
  const lastMonRev = completedPayments.filter(p => {
    const d = new Date(p.paid_at!);
    return d >= lastMonthStart && d < currentMonthStart;
  }).reduce((s, p) => s + (parseFloat(p.amount) || 0), 0);
  
  const revChangeStr = lastMonRev > 0 
    ? `${((currentMonRev - lastMonRev) / lastMonRev * 100).toFixed(1)}% vs last month`
    : `New revenue this period`;
  const revChangeType = currentMonRev >= lastMonRev ? "up" : "down";

  // Subscriptions
  const currentMonSubs = filteredSubscriptions.filter(s => new Date(s.created_at) >= currentMonthStart).length;
  const lastMonSubs = filteredSubscriptions.filter(s => {
    const d = new Date(s.created_at);
    return d >= lastMonthStart && d < currentMonthStart;
  }).length;
  const subChangeStr = lastMonSubs > 0
    ? `${(((currentMonSubs - lastMonSubs) / lastMonSubs) * 100).toFixed(1)}% vs last month`
    : `New tracking started`;
  const subChangeType = currentMonSubs >= lastMonSubs ? "up" : "down";

  // Members
  const activeMembersCount = filteredMembers.filter(m => !m.is_suspended).length;

  // Transactions list
  const recentTransactions = [...filteredPayments].sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()).slice(0, 5);

  // Facility Load (Today's sessions)
  const todayStr = new Date().toISOString().split("T")[0];
  const todaySessions = sessions.filter((s) => s.date === todayStr && !s.is_cancelled);
  const totalAttendanceToday = todaySessions.reduce((s, x) => s + (x.confirmed_count || 0), 0);
  const totalCapacityToday = todaySessions.reduce((s, x) => s + (x.max_members || 0), 0);
  const facilityLoad = totalCapacityToday > 0 ? Math.round((totalAttendanceToday / totalCapacityToday) * 100) : 0;

  // Class Popularity
  const classStats = useMemo(() => {
    const stats: Record<string, { members: number; capacity: number }> = {};
    sessions.filter(s => !s.is_cancelled).forEach(s => {
      const name = s.course_name || "Unknown class";
      if (!stats[name]) stats[name] = { members: 0, capacity: 0 };
      stats[name].members += (s.confirmed_count || 0);
      stats[name].capacity += (s.max_members || 0);
    });
    
    return Object.entries(stats)
      .map(([name, data]) => ({
        name,
        percentage: data.capacity > 0 ? Math.round((data.members / data.capacity) * 100) : 0
      }))
      .sort((a, b) => b.percentage - a.percentage)
      .slice(0, 4);
  }, [sessions]);

  /* ── Export Handlers ────────────────────────────────────────────────── */
  const handleExportCSV = () => {
    const headers = ["ID", "Member", "Amount", "Status", "Date"];
    const rows = filteredPayments.map(p => [
      p.id,
      p.member_name || "Unknown",
      p.amount,
      p.status,
      new Date(p.created_at).toLocaleDateString()
    ]);
    
    const csvContent = [headers.join(","), ...rows.map(r => r.join(","))].join("\n");
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `fittech_analytics_report_${timeFilter}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleExportPDF = () => {
    const doc = new jsPDF();
    doc.text(`Analytics Report (${timeFilter === "all" ? "All Time" : "Last 30 Days"})`, 14, 15);
    
    const tableData = filteredPayments.map(p => [
      String(p.id),
      p.member_name || "Unknown",
      `${parseFloat(p.amount).toFixed(2)} DA`,
      p.status.toUpperCase(),
      new Date(p.created_at).toLocaleDateString()
    ]);

    autoTable(doc, {
      head: [["ID", "Member", "Amount", "Status", "Date"]],
      body: tableData,
      startY: 20,
    });

    doc.save(`fittech_analytics_report_${timeFilter}.pdf`);
  };

  const handleExportJSON = () => {
    const jsonContent = JSON.stringify(filteredPayments, null, 2);
    const blob = new Blob([jsonContent], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `fittech_analytics_report_${timeFilter}.json`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleExportXML = () => {
    let xmlContent = '<?xml version="1.0" encoding="UTF-8"?>\n<payments>\n';
    filteredPayments.forEach(p => {
      xmlContent += `  <payment>\n`;
      xmlContent += `    <id>${p.id}</id>\n`;
      xmlContent += `    <member>${p.member_name ? p.member_name.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') : 'Unknown'}</member>\n`;
      xmlContent += `    <amount>${p.amount}</amount>\n`;
      xmlContent += `    <status>${p.status}</status>\n`;
      xmlContent += `    <date>${new Date(p.created_at).toISOString()}</date>\n`;
      xmlContent += `  </payment>\n`;
    });
    xmlContent += '</payments>';
    const blob = new Blob([xmlContent], { type: 'application/xml' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `fittech_analytics_report_${timeFilter}.xml`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  if (loading) {
    return (
      <>
        <AdminHeader searchPlaceholder="Search analytics data..." actionLabel="Add Entry" />
        <div className="p-6 md:p-8 flex items-center justify-center min-h-[60vh]">
          <div className="flex flex-col items-center gap-4">
            <div className="w-10 h-10 rounded-full border-2 border-brand-green/20 border-t-brand-green animate-spin" />
            <p className="text-text-muted text-sm animate-pulse">Loading reports...</p>
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      <AdminHeader searchPlaceholder="Search analytics data..." actionLabel="Add Entry" />

      <div className="p-6 md:p-8 space-y-6 animate-fade-in-up">
        {/* Page Title */}
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-3xl font-black text-white uppercase tracking-wide">Reports & Analytics</h1>
            <p className="text-sm text-text-muted mt-1">Real-time performance metrics and architectural data insights.</p>
          </div>
          <div className="flex items-center gap-3">
            <button 
              onClick={() => setTimeFilter(f => f === "all" ? "30days" : "all")}
              className={`px-4 py-2.5 text-xs font-bold rounded-xl transition-all ${
                timeFilter === "30days" 
                  ? "bg-brand-green text-[#0B1120] hover:bg-brand-green-light" 
                  : "text-white bg-white/10 border border-white/10 hover:bg-white/15"
              }`}
            >
              {timeFilter === "30days" ? "SHOW ALL TIME" : "LAST 30 DAYS"}
            </button>
            <div className="relative">
              <button 
                onClick={() => setShowExportMenu(!showExportMenu)}
                className="px-4 py-2.5 text-xs font-bold text-white bg-white/10 border border-white/10 rounded-xl hover:bg-white/15 transition-all flex items-center gap-2"
              >
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 16.5v2.25A2.25 2.25 0 005.25 21h13.5A2.25 2.25 0 0021 18.75V16.5M16.5 12L12 16.5m0 0L7.5 12m4.5 4.5V3" />
                </svg>
                EXPORT AS
              </button>
              
              {showExportMenu && (
                <>
                  <div 
                    className="fixed inset-0 z-40" 
                    onClick={() => setShowExportMenu(false)}
                  />
                  <div className="absolute right-0 mt-2 w-32 bg-[#1a2332] border border-white/10 rounded-xl shadow-xl overflow-hidden z-50 animate-fade-in-up">
                    <button onClick={() => { handleExportJSON(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">JSON</button>
                    <button onClick={() => { handleExportXML(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">XML</button>
                    <button onClick={() => { handleExportCSV(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">CSV</button>
                    <button onClick={() => { handleExportPDF(); setShowExportMenu(false); }} className="w-full text-left px-4 py-2 text-xs font-bold text-white hover:bg-white/10 transition-colors">PDF</button>
                  </div>
                </>
              )}
            </div>
          </div>
        </div>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <StatCard
            label="Total Revenue"
            value={`${totalRevenue.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })} DA`}
            change={revChangeStr}
            changeType={revChangeType}
          />
          <StatCard
            label={`New Subscriptions (${timeFilter === "all" ? "This Month" : "30 Days"})`}
            value={currentMonSubs.toString()}
            change={subChangeStr}
            changeType={subChangeType}
          />
          <StatCard
            label="Active Members"
            value={activeMembersCount.toLocaleString()}
            subtitle={`Out of ${filteredMembers.length} total`}
            extra={
              <div className="flex gap-0.5 items-end h-6">
                {[50, 60, 55, 70, 65, 80, 75].map((v, i) => (
                  <div key={i} className="w-1.5 bg-brand-green/50 rounded-t-sm" style={{ height: `${(v / 100) * 100}%` }} />
                ))}
              </div>
            }
          />
        </div>

        {/* Charts Row */}
        <div className="grid grid-cols-1 lg:grid-cols-[1fr_320px] gap-4">
          {/* Revenue Growth Chart */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-sm font-bold text-white uppercase tracking-wider">
                {timeFilter === "30days" ? "Daily Revenue Growth (30 Days)" : "Monthly Revenue Growth"}
              </h2>
              <span className="flex items-center gap-1.5 text-xs text-text-muted">
                <span className="w-2 h-2 rounded-full bg-brand-green" /> Revenue
              </span>
            </div>
            <RevenueChart payments={payments} timeFilter={timeFilter} />
          </div>

          {/* Current Facility Load */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6 flex flex-col items-center">
            <h2 className="text-sm font-bold text-white uppercase tracking-wider self-start mb-6">Today&apos;s Facility Load</h2>
            <FacilityGauge percentage={facilityLoad} />
            <div className="w-full mt-4 space-y-1 text-center">
              <p className="text-xs text-text-muted">{totalAttendanceToday} total attendances booked today.</p>
              <p className="text-xs text-text-muted">Out of {totalCapacityToday} maximum capacity.</p>
            </div>
          </div>
        </div>

        {/* Bottom Row: Class Popularity + Recent Transactions */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {/* Class Popularity */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
            <h2 className="text-sm font-bold text-white uppercase tracking-wider mb-6">Class Popularity</h2>
            <div className="space-y-5">
              {classStats.length === 0 ? (
                <p className="text-sm text-text-muted py-2 text-center">No class data available.</p>
              ) : (
                classStats.map((cls, i) => (
                  <PopularityBar 
                    key={cls.name} 
                    name={cls.name} 
                    percentage={cls.percentage} 
                    color={i % 2 === 0 ? "bg-brand-green" : "bg-blue-500"} 
                  />
                ))
              )}
            </div>
          </div>

          {/* Recent Transactions */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-sm font-bold text-white uppercase tracking-wider">Recent Transactions</h2>
              <Link href="/admin/subscriptions" className="text-xs font-semibold text-brand-green hover:text-brand-green-light transition-colors">
                View All
              </Link>
            </div>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-[10px] font-bold tracking-[0.15em] text-text-muted/50 uppercase border-b border-white/5">
                    <th className="text-left py-2">User</th>
                    <th className="text-left py-2">Status</th>
                    <th className="text-right py-2">Amount</th>
                  </tr>
                </thead>
                <tbody>
                  {recentTransactions.length === 0 ? (
                    <tr>
                      <td colSpan={3} className="py-4 text-center text-text-muted">No recent transactions.</td>
                    </tr>
                  ) : (
                    recentTransactions.map((t) => {
                      const name = t.member_name || "Unknown User";
                      const initials = name.split(" ").map(n => n[0]).join("").slice(0,2).toUpperCase();
                      const statusColor = t.status === "completed" 
                        ? "text-brand-green bg-brand-green/10" 
                        : t.status === "failed" 
                          ? "text-red-400 bg-red-500/10" 
                          : "text-amber-400 bg-amber-500/10";
                      
                      return (
                        <tr key={t.id} className="border-b border-white/5 last:border-0 hover:bg-white/3 transition-colors">
                          <td className="py-3">
                            <div className="flex items-center gap-2">
                              <div className="w-8 h-8 rounded-full bg-brand-green/15 flex items-center justify-center text-brand-green text-[10px] font-bold truncate">
                                {initials}
                              </div>
                              <span className="font-medium text-white">{name}</span>
                            </div>
                          </td>
                          <td className="py-3">
                            <span className={`text-[10px] font-bold uppercase tracking-wider px-2 py-1 rounded-md ${statusColor}`}>
                              {t.status}
                            </span>
                          </td>
                          <td className="py-3 text-right font-bold text-white truncate max-w-[80px]">
                            {parseFloat(t.amount).toLocaleString(undefined, { minimumFractionDigits: 2 })} DA
                          </td>
                        </tr>
                      );
                    })
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
