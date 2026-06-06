"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useAuthStore } from "@/lib/stores/authStore";
import { LayoutDashboard, Users, Dumbbell, BarChart2, SlidersHorizontal, Settings, LogOut, Calendar, CreditCard, MessageSquare, MapPin } from "lucide-react";

const navItems = [
  {
    href: "/admin",
    label: "Dashboard",
    icon: <LayoutDashboard className="w-5 h-5" />,
  },
  {
    href: "/admin/members",
    label: "Members",
    icon: <Users className="w-5 h-5" />,
  },
  {
    href: "/admin/coaches",
    label: "Coaches",
    icon: <Dumbbell className="w-5 h-5" />,
  },
  {
    href: "/admin/reports",
    label: "Reports",
    icon: <BarChart2 className="w-5 h-5" />,
  },
  {
    href: "/admin/equipment",
    label: "Equipment",
    icon: <SlidersHorizontal className="w-5 h-5" />,
  },
  {
    href: "/admin/sessions",
    label: "Courses",
    icon: <Calendar className="w-5 h-5" />,
  },
  {
    href: "/admin/rooms",
    label: "Rooms",
    icon: <MapPin className="w-5 h-5" />,
  },
  {
    href: "/admin/subscriptions",
    label: "Subscriptions",
    icon: <CreditCard className="w-5 h-5" />,
  },
  {
    href: "/admin/messages",
    label: "Messages",
    icon: <MessageSquare className="w-5 h-5" />,
  },
];

export default function AdminSidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const user = useAuthStore((s) => s.user);
  const logout = useAuthStore((s) => s.logout);

  const isActive = (href: string) => {
    if (href === "/admin") return pathname === "/admin";
    return pathname.startsWith(href);
  };

  return (
    <aside className="w-full md:w-64 flex-shrink-0 bg-[#0d1520] border-b md:border-b-0 md:border-r border-white/5 flex flex-col md:h-screen">
      {/* Logo */}
      <div className="p-5 pb-3">
        <Link href="/admin" className="flex items-center gap-3 group">
          <div className="w-9 h-9 rounded-lg bg-gradient-to-br from-brand-green to-brand-green-dark flex items-center justify-center text-[#0B1120] font-black text-sm shadow-lg shadow-brand-green/20">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
            </svg>
          </div>
          <div>
            <span className="text-base font-black tracking-wider text-white block leading-tight">FITTECH</span>
            <span className="text-brand-green text-[10px] font-bold tracking-widest uppercase">Admin</span>
          </div>
        </Link>
        <p className="text-[9px] font-medium tracking-wider text-text-muted/50 uppercase mt-1 ml-12">Performance Architect</p>
      </div>

      {/* Desktop Nav */}
      <nav className="flex-1 px-3 space-y-0.5 overflow-y-auto hidden md:block mt-2">
        {navItems.map((item) => {
          const active = isActive(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-300 group relative ${
                active
                  ? "text-brand-green font-bold"
                  : "text-text-muted font-medium hover:text-white hover:bg-white/5"
              }`}
            >
              {active && (
                <div className="absolute left-0 top-1/2 -translate-y-1/2 w-[3px] h-7 bg-brand-green rounded-r-full shadow-[0_0_10px_rgba(46,204,112,0.6)]" />
              )}
              <span className={`transition-all duration-300 ${active ? 'text-brand-green' : 'text-text-muted/60 group-hover:text-white'}`}>
                {item.icon}
              </span>
              {item.label}
            </Link>
          );
        })}
      </nav>

      {/* Mobile Nav */}
      <div className="md:hidden flex overflow-x-auto px-4 pb-4 space-x-2">
        {navItems.map((item) => {
          const active = isActive(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`whitespace-nowrap px-4 py-2.5 rounded-xl text-sm flex items-center gap-2 transition-all duration-300 ${
                active
                  ? "bg-brand-green/10 text-brand-green font-bold border border-brand-green/20"
                  : "text-text-muted bg-white/5"
              }`}
            >
              {item.icon}
              {item.label}
            </Link>
          );
        })}
      </div>

      {/* Bottom Section */}
      <div className="hidden md:block mt-auto">
        {/* Divider */}
        <div className="mx-4 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent" />

        {/* Settings & Logout */}
        <div className="px-3 py-2 space-y-0.5">
          <Link
            href="/admin/settings"
            className="flex items-center gap-3 px-4 py-2.5 rounded-xl text-text-muted/70 text-sm font-medium hover:text-white hover:bg-white/5 transition-all duration-300"
          >
            <Settings className="w-4 h-4" />
            Settings
          </Link>
          <button
            onClick={() => { logout(); router.push("/login"); }}
            className="w-full flex items-center gap-3 px-4 py-2.5 rounded-xl text-text-muted/70 text-sm font-medium hover:text-red-400 hover:bg-red-500/10 transition-all duration-300"
          >
            <LogOut className="w-4 h-4" />
            Logout
          </button>
        </div>

        {/* User Profile */}
        <div className="p-4 border-t border-white/5 bg-[#080d16]">
          <div className="flex items-center gap-3 px-1">
            <div className="relative flex-shrink-0">
              <div className="w-10 h-10 rounded-full bg-gradient-to-br from-brand-green/30 to-brand-green-dark/30 border-2 border-brand-green/40 flex items-center justify-center text-brand-green font-bold text-sm">
                {user?.first_name?.[0]?.toUpperCase() || "A"}
              </div>
              <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-brand-green rounded-full border-2 border-[#080d16]" />
            </div>
            <div className="overflow-hidden flex-1 min-w-0">
              <p className="text-sm font-bold text-white truncate">
                {user?.first_name || "Alex"} {user?.last_name || "Johnson"}
              </p>
              <p className="text-[11px] text-text-muted truncate">
                {user?.role === 'admin' ? 'System Admin' : 'Head Trainer'}
              </p>
            </div>
          </div>
        </div>
      </div>
    </aside>
  );
}
