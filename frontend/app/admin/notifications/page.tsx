"use client";

import { useEffect, useState } from "react";
import AdminHeader from "@/components/admin/AdminHeader";
import { getAdminNotificationsApi, markAdminNotificationReadApi, markAllAdminNotificationsReadApi, AdminNotification } from "@/lib/api";
import { useAuthStore } from "@/lib/stores/authStore";
import { formatTimeAgo } from "@/lib/utils";

import { useRouter } from "next/navigation";

export default function AdminNotificationsPage() {
  const [notifications, setNotifications] = useState<AdminNotification[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [activeFilter, setActiveFilter] = useState("ALL");
  const token = useAuthStore((s) => s.accessToken);
  const router = useRouter();

  const fetchNotifications = async () => {
    if (!token) return;
    try {
      const data = await getAdminNotificationsApi(token);
      setNotifications(data);
    } catch (error) {
      console.error("Failed to fetch notifications:", error);
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchNotifications();
  }, [token]);

  const handleMarkRead = async (id: number) => {
    if (!token) return;
    try {
      await markAdminNotificationReadApi(id, token);
      setNotifications((prev) =>
        prev.map((n) => (n.id === id ? { ...n, is_read: true } : n))
      );
    } catch (error) {
      console.error("Failed to mark as read:", error);
    }
  };

  const handleActionClick = async (id: number, type: string) => {
    await handleMarkRead(id);
    switch (type) {
      case "member":
        router.push("/admin/members");
        break;
      case "equipment":
        router.push("/admin/equipment");
        break;
      case "payment":
        router.push("/admin/reports");
        break;
      case "coach":
        router.push("/admin/messages");
        break;
      default:
        break;
    }
  };

  const filteredNotifications = notifications.filter((n) => {
    if (activeFilter === "ALL") return true;
    if (activeFilter === "ALERTS" && n.notification_type === "equipment") return true;
    if (activeFilter === "PAYMENTS" && n.notification_type === "payment") return true;
    if (activeFilter === "MEMBERS" && n.notification_type === "member") return true;
    return false;
  });

  const getNotificationStyles = (type: string, isRead: boolean) => {
    if (isRead) {
      return {
        bg: "bg-[#71717A]/20",
        tagColor: "text-[#A1A1AA]",
        titleColor: "text-white",
        iconColor: "text-[#A1A1AA]",
        iconBg: "bg-[#71717A]/10",
        btnPrimary: "bg-[#71717A]/20 text-[#A1A1AA] hover:bg-[#71717A]/30",
        tagText: type.toUpperCase(),
        btnText: "VIEW",
      };
    }
    
    switch (type) {
      case "member":
        return {
          bg: "bg-[#111827]",
          tagColor: "text-[#22C55E]",
          titleColor: "text-white",
          iconColor: "text-[#22C55E]",
          iconBg: "bg-[#22C55E]/10",
          btnPrimary: "bg-[#22C55E] text-[#0B1120] hover:bg-[#22C55E]/90",
          tagText: "MEMBERSHIP",
          btnText: "VIEW PROFILE",
        };
      case "equipment":
        return {
          bg: "bg-[#111827]",
          tagColor: "text-[#EF4444]",
          titleColor: "text-white",
          iconColor: "text-[#EF4444]",
          iconBg: "bg-[#EF4444]/10",
          btnPrimary: "bg-[#EF4444] text-white hover:bg-[#EF4444]/90",
          tagText: "CRITICAL ALERT",
          btnText: "DISPATCH TECH",
        };
      case "payment":
        return {
          bg: "bg-[#111827]",
          tagColor: "text-[#38BDF8]",
          titleColor: "text-white",
          iconColor: "text-[#38BDF8]",
          iconBg: "bg-[#38BDF8]/10",
          btnPrimary: "bg-[#38BDF8] text-[#0B1120] hover:bg-[#38BDF8]/90",
          tagText: "FINANCE",
          btnText: "VIEW INVOICE",
        };
      case "coach":
        return {
          bg: "bg-[#111827]",
          tagColor: "text-[#F59E0B]",
          titleColor: "text-white",
          iconColor: "text-[#F59E0B]",
          iconBg: "bg-[#F59E0B]/10",
          btnPrimary: "bg-[#F59E0B] text-[#0B1120] hover:bg-[#F59E0B]/90",
          tagText: "COACH MESSAGE",
          btnText: "READ REPORT",
        };
      default: // system
        return {
          bg: "bg-[#111827]",
          tagColor: "text-[#A1A1AA]",
          titleColor: "text-white",
          iconColor: "text-[#A1A1AA]",
          iconBg: "bg-[#71717A]/10",
          btnPrimary: "bg-[#71717A]/20 text-[#A1A1AA] hover:bg-[#71717A]/30",
          tagText: "SYSTEM UPDATE",
          btnText: "VIEW DETAILS",
        };
    }
  };

  const getIcon = (type: string) => {
    switch (type) {
      case "member":
        return (
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-6 h-6">
            <path strokeLinecap="round" strokeLinejoin="round" d="M19 7.5v3m0 0v3m0-3h3m-3 0h-3m-2.25-4.125a3.375 3.375 0 11-6.75 0 3.375 3.375 0 016.75 0zM4 19.235v-.11a6.375 6.375 0 0112.75 0v.109A12.318 12.318 0 0110.374 21c-2.331 0-4.512-.645-6.374-1.766z" />
          </svg>
        );
      case "equipment":
        return (
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-6 h-6">
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
        );
      case "payment":
        return (
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-6 h-6">
            <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 18.75a60.07 60.07 0 0115.797 2.101c.727.198 1.453-.342 1.453-1.096V18.75M3.75 4.5v.75A.75.75 0 013 6h-.75m0 0v-.375c0-.621.504-1.125 1.125-1.125H20.25M2.25 6v9m18-10.5v.75c0 .414.336.75.75.75h.75m-1.5-1.5h.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125h-.375m1.5-1.5H21a.75.75 0 00-.75.75v.75m0 0H3.75m0 0h-.375a1.125 1.125 0 01-1.125-1.125V15m1.5 1.5v-.75A.75.75 0 003 15h-.75M15 10.5a3 3 0 11-6 0 3 3 0 016 0z" />
          </svg>
        );
      case "coach":
        return (
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-6 h-6">
            <path strokeLinecap="round" strokeLinejoin="round" d="M8.625 9.75a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375m-13.5 3.01c0 1.6 1.123 2.994 2.707 3.227 1.087.16 2.185.283 3.293.369V21l4.184-4.183a1.14 1.14 0 01.778-.332 48.294 48.294 0 005.83-.498c1.585-.233 2.708-1.626 2.708-3.228V6.741c0-1.602-1.123-2.995-2.707-3.228A48.394 48.394 0 0012 3c-2.392 0-4.744.175-7.043.513C3.373 3.746 2.25 5.14 2.25 6.741v6.018z" />
          </svg>
        );
      default:
        return (
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-6 h-6">
            <path strokeLinecap="round" strokeLinejoin="round" d="M16.023 9.348h4.992v-.001M2.985 19.644v-4.992m0 0h4.992m-4.993 0l3.181 3.183a8.25 8.25 0 0013.803-3.7M4.031 9.865a8.25 8.25 0 0113.803-3.7l3.181 3.182m0-4.991v4.99" />
          </svg>
        );
    }
  };

  return (
    <div className="flex flex-col h-full bg-[#0B1120] overflow-hidden">
      <AdminHeader />
      
      <div className="flex-1 overflow-y-auto p-8">
        <div className="max-w-5xl mx-auto space-y-8">
          
          {/* Filters */}
          <div className="flex items-center gap-6 font-bold text-xs tracking-wider">
            {["ALL", "ALERTS", "PAYMENTS", "MEMBERS"].map((filter) => (
              <button
                key={filter}
                onClick={() => setActiveFilter(filter)}
                className={`px-4 py-2 rounded-full transition-colors ${
                  activeFilter === filter
                    ? "bg-[#E8F8EE] text-[#22C55E]"
                    : "text-[#A1A1AA] hover:text-white"
                }`}
              >
                {filter}
              </button>
            ))}
          </div>

          {/* Top Cards */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="md:col-span-2 bg-[#0E1524] rounded-xl p-8 relative overflow-hidden flex flex-col justify-between">
              <div>
                <p className="text-[#22C55E] text-xs font-bold tracking-widest mb-2">LIVE METRIC</p>
                <h2 className="text-white text-4xl font-extrabold mb-4">98.4% SYSTEM UPTIME</h2>
                <p className="text-[#A1A1AA] max-w-sm text-sm leading-relaxed relative z-10">
                  <span className="w-1 h-full bg-[#22C55E] absolute -left-4 top-0" />
                  All FitTech protocols are within normal operating parameters. Zone B humidity is the only outlier.
                </p>
              </div>
              <div className="absolute right-0 bottom-0 opacity-20 pointer-events-none">
                <svg width="250" height="150" viewBox="0 0 250 150" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M0 150L40 90L90 120L170 30L250 90V150H0Z" fill="currentColor" className="text-white"/>
                  <path d="M40 90L90 120L170 30L250 90" stroke="currentColor" strokeWidth="8" strokeLinecap="round" strokeLinejoin="round" className="text-white"/>
                  <circle cx="40" cy="90" r="10" fill="currentColor" className="text-white"/>
                  <circle cx="90" cy="120" r="10" fill="currentColor" className="text-white"/>
                  <circle cx="170" cy="30" r="10" fill="currentColor" className="text-white"/>
                  <circle cx="250" cy="90" r="10" fill="currentColor" className="text-white"/>
                </svg>
              </div>
            </div>
            <div className="bg-[#22C55E] rounded-xl p-8 flex flex-col items-center justify-center text-[#0B1120] text-center">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-12 h-12 mb-2">
                <path fillRule="evenodd" d="M14.615 1.595a.75.75 0 01.359.852L12.982 9.75h7.268a.75.75 0 01.548 1.262l-10.5 11.25a.75.75 0 01-1.272-.71l1.992-7.302H3.75a.75.75 0 01-.548-1.262l10.5-11.25a.75.75 0 01.913-.143z" clipRule="evenodd" />
              </svg>
              <p className="text-xs font-bold tracking-widest mb-1">NEW ACTIONS</p>
              <h2 className="text-5xl font-black">12</h2>
            </div>
          </div>

          {/* Notifications List */}
          <div className="space-y-4">
            {isLoading ? (
              <div className="text-center text-text-muted py-8">Loading notifications...</div>
            ) : filteredNotifications.length === 0 ? (
              <div className="text-center text-text-muted py-8">No notifications found.</div>
            ) : (
              <>
                {filteredNotifications.filter(n => !n.is_read).map((notification) => {
                  const styles = getNotificationStyles(notification.notification_type, notification.is_read);
                  return (
                    <div key={notification.id} className={`${styles.bg} rounded-xl p-6 flex flex-col sm:flex-row sm:items-center gap-6 border border-white/5`}>
                      <div className={`w-14 h-14 rounded-xl flex items-center justify-center shrink-0 ${styles.iconBg} ${styles.iconColor}`}>
                        {getIcon(notification.notification_type)}
                      </div>
                      <div className="flex-1">
                        <p className={`text-[10px] font-bold tracking-widest uppercase mb-1 ${styles.tagColor}`}>
                          {styles.tagText}
                        </p>
                        <h3 className={`text-xl font-bold uppercase ${styles.titleColor} mb-2`}>
                          {notification.title}
                        </h3>
                        <p className="text-[#A1A1AA] text-sm">
                          {notification.message}
                        </p>
                      </div>
                      <div className="flex flex-col sm:items-end gap-4 shrink-0">
                        <p className="text-[#A1A1AA] text-xs font-medium uppercase tracking-wider">
                          {formatTimeAgo(notification.created_at)}
                        </p>
                        <div className="flex items-center gap-3">
                          <button
                            onClick={() => handleActionClick(notification.id, notification.notification_type)}
                            className={`px-5 py-2.5 rounded-lg text-xs font-bold tracking-wider uppercase transition-colors ${styles.btnPrimary}`}
                          >
                            {styles.btnText}
                          </button>
                          <button 
                            onClick={() => handleMarkRead(notification.id)}
                            className="px-5 py-2.5 rounded-lg bg-white/10 text-white text-xs font-bold tracking-wider uppercase hover:bg-white/20 transition-colors"
                          >
                            {notification.notification_type === 'coach' ? 'REPLY' : notification.notification_type === 'equipment' ? 'OVERRIDE' : 'DISMISS'}
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })}

                {filteredNotifications.filter(n => n.is_read).length > 0 && (
                  <>
                    <div className="py-6 flex items-center justify-center text-center">
                      <span className="text-[#71717A] text-[10px] font-black tracking-[0.2em] uppercase">
                        Older Notifications
                      </span>
                    </div>

                    {filteredNotifications.filter(n => n.is_read).map((notification) => {
                      const styles = getNotificationStyles(notification.notification_type, notification.is_read);
                      return (
                        <div key={notification.id} className={`${styles.bg} rounded-xl p-6 flex flex-col sm:flex-row sm:items-center gap-6 border border-transparent`}>
                          <div className={`w-14 h-14 rounded-xl flex items-center justify-center shrink-0 ${styles.iconBg} ${styles.iconColor}`}>
                            {getIcon(notification.notification_type)}
                          </div>
                          <div className="flex-1">
                            <p className={`text-[10px] font-bold tracking-widest uppercase mb-1 ${styles.tagColor}`}>
                              {styles.tagText}
                            </p>
                            <h3 className={`text-xl font-bold uppercase ${styles.titleColor} mb-2`}>
                              {notification.title}
                            </h3>
                            <p className="text-[#A1A1AA] text-sm">
                              {notification.message}
                            </p>
                          </div>
                          <div className="flex flex-col sm:items-end gap-4 shrink-0">
                            <p className="text-[#A1A1AA] text-xs font-medium uppercase tracking-wider">
                              {formatTimeAgo(notification.created_at)}
                            </p>
                          </div>
                        </div>
                      );
                    })}
                  </>
                )}
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
