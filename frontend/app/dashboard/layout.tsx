"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect } from "react";
import { useAuthStore } from "@/lib/stores/authStore";

const navItems = [
  {
    href: "/dashboard",
    label: "Dashboard",
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5">
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 6A2.25 2.25 0 016 3.75h2.25A2.25 2.25 0 0110.5 6v2.25a2.25 2.25 0 01-2.25 2.25H6a2.25 2.25 0 01-2.25-2.25V6zM3.75 15.75A2.25 2.25 0 016 13.5h2.25a2.25 2.25 0 012.25 2.25V18a2.25 2.25 0 01-2.25 2.25H6A2.25 2.25 0 013.75 18v-2.25zM13.5 6a2.25 2.25 0 012.25-2.25H18A2.25 2.25 0 0120.25 6v2.25A2.25 2.25 0 0118 10.5h-2.25a2.25 2.25 0 01-2.25-2.25V6zM13.5 15.75a2.25 2.25 0 012.25-2.25H18a2.25 2.25 0 012.25 2.25V18A2.25 2.25 0 0118 20.25h-2.25A2.25 2.25 0 0113.5 18v-2.25z" />
      </svg>
    ),
  },
  {
    href: "/dashboard/profile",
    label: "Profile Settings",
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5">
        <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
      </svg>
    ),
  },
];

function getGreeting() {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

function getBreadcrumb(pathname: string) {
  if (pathname === "/dashboard") return "Overview";
  if (pathname === "/dashboard/profile") return "Profile Settings";
  return "Dashboard";
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const isHydrated = useAuthStore((s) => s.isHydrated);
  const user = useAuthStore((s) => s.user);
  const logout = useAuthStore((s) => s.logout);
  const pathname = usePathname();

  useEffect(() => {
    if (isHydrated) {
      if (!isAuthenticated) {
        router.replace("/login");
      } else if (user?.role === 'admin') {
        router.replace("/admin");
      }
    }
  }, [isHydrated, isAuthenticated, user, router]);

  if (!isHydrated || !isAuthenticated) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-bg-auth">
        <div className="flex flex-col items-center gap-4">
          <div className="relative">
            <div className="w-12 h-12 rounded-full border-2 border-brand-green/20 border-t-brand-green animate-spin" />
          </div>
          <p className="text-text-muted text-sm animate-pulse">Loading your dashboard...</p>
        </div>
      </div>
    );
  }

  const roleColor = user?.role === 'admin' ? 'text-red-400 bg-red-500/10 border-red-500/20' 
    : user?.role === 'coach' ? 'text-amber-400 bg-amber-500/10 border-amber-500/20' 
    : 'text-brand-green bg-brand-green/10 border-brand-green/20';

  return (
    <div className="h-screen overflow-hidden bg-bg-auth text-white flex flex-col md:flex-row font-sans">
      {/* Sidebar */}
      <aside className="w-full md:w-72 flex-shrink-0 bg-surface-elevated/60 backdrop-blur-xl border-b md:border-b-0 md:border-r border-white/5 flex flex-col shadow-2xl z-10 md:h-screen">
        {/* Logo + Home Link */}
        <div className="p-6 pb-4">
          <Link href="/" className="flex items-center gap-3 group">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-brand-green to-brand-green-dark flex items-center justify-center text-bg-main font-black text-xl shadow-lg shadow-brand-green/20 transition-all duration-300 group-hover:scale-105 group-hover:shadow-brand-green/30">
              F
            </div>
            <span className="text-xl font-black tracking-widest text-white">
              FITTECH
            </span>
          </Link>
        </div>

        {/* Nav Section Label */}
        <div className="px-6 pt-4 pb-2">
          <p className="text-[10px] font-bold tracking-[0.2em] text-text-muted/60 uppercase">Navigation</p>
        </div>

        {/* Desktop Nav */}
        <nav className="flex-1 px-3 space-y-1 overflow-y-auto hidden md:block">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 px-4 py-3 rounded-xl transition-all duration-300 group relative ${
                  isActive
                    ? "bg-brand-green/10 text-brand-green font-bold"
                    : "text-text-muted font-medium hover:text-white hover:bg-white/5"
                }`}
              >
                {/* Active indicator bar */}
                {isActive && (
                  <div className="absolute left-0 top-1/2 -translate-y-1/2 w-1 h-6 bg-brand-green rounded-r-full shadow-[0_0_8px_rgba(46,204,112,0.5)]" />
                )}
                <span className={`transition-all duration-300 ${isActive ? 'text-brand-green' : 'text-text-muted/70 group-hover:text-white'}`}>
                  {item.icon}
                </span>
                {item.label}
              </Link>
            );
          })}
        </nav>

        {/* Mobile Nav */}
        <div className="md:hidden flex overflow-x-auto px-4 pb-4 space-x-2 hide-scrollbar">
          {navItems.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`whitespace-nowrap px-4 py-2.5 rounded-xl text-sm flex items-center gap-2 transition-all duration-300 ${
                  isActive
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

        {/* Divider */}
        <div className="mx-4 h-px bg-gradient-to-r from-transparent via-white/10 to-transparent hidden md:block" />

        {/* Back to Home */}
        <div className="px-3 py-3 hidden md:block">
          <Link
            href="/"
            className="flex items-center gap-3 px-4 py-2.5 rounded-xl text-text-muted/70 text-sm font-medium hover:text-white hover:bg-white/5 transition-all duration-300 group"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4 transition-transform duration-300 group-hover:-translate-x-1">
              <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 19.5L3 12m0 0l7.5-7.5M3 12h18" />
            </svg>
            Back to Home
          </Link>
        </div>

        {/* User Profile Section */}
        <div className="p-4 border-t border-white/5 bg-bg-auth/40 hidden md:block">
          <div className="flex items-center gap-3 mb-3 px-1">
            {/* Gradient avatar ring */}
            <div className="relative flex-shrink-0">
              <div className="absolute inset-0 bg-gradient-to-br from-brand-green to-brand-green-dark rounded-full blur-sm opacity-40" />
              <div className="relative w-11 h-11 rounded-full bg-gradient-to-br from-brand-green/30 to-brand-green-dark/30 border-2 border-brand-green/40 flex items-center justify-center text-brand-green font-bold text-lg shadow-inner">
                {user?.first_name?.[0]?.toUpperCase() || "U"}
              </div>
            </div>
            <div className="overflow-hidden flex-1 min-w-0">
              <p className="text-sm font-bold text-white truncate">
                {user?.first_name} {user?.last_name}
              </p>
              <div className="flex items-center gap-2">
                <span className={`text-[10px] font-bold uppercase tracking-wider px-1.5 py-0.5 rounded border ${roleColor}`}>
                  {user?.role || "member"}
                </span>
              </div>
            </div>
          </div>
          <button
            onClick={() => { logout(); router.push("/login"); }}
            className="w-full flex items-center gap-2 justify-center px-4 py-2.5 text-red-400/80 hover:text-red-300 hover:bg-red-500/10 rounded-xl text-sm font-semibold transition-all duration-300 border border-transparent hover:border-red-500/15"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-6a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9" />
            </svg>
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main className="flex-1 overflow-y-auto">
        {/* Top Header Bar */}
        <div className="sticky top-0 z-20 bg-bg-auth/80 backdrop-blur-xl border-b border-white/5">
          <div className="px-6 md:px-10 py-4 flex items-center justify-between max-w-6xl">
            <div>
              <p className="text-xs text-text-muted/60 font-medium">
                Dashboard / <span className="text-text-muted">{getBreadcrumb(pathname)}</span>
              </p>
              <h2 className="text-lg font-bold text-white mt-0.5">
                {getGreeting()}, <span className="text-brand-green">{user?.first_name || "there"}</span> 👋
              </h2>
            </div>

            {/* Quick Actions on Header */}
            <div className="flex items-center gap-3">
              {/* Email status indicator */}
              <div className={`hidden sm:flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold ${
                user?.email_verified 
                  ? 'bg-brand-green/10 text-brand-green border border-brand-green/20' 
                  : 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
              }`}>
                <div className={`w-1.5 h-1.5 rounded-full ${user?.email_verified ? 'bg-brand-green animate-pulse' : 'bg-amber-400'}`} />
                {user?.email_verified ? "Verified" : "Unverified"}
              </div>

              {/* Mobile user avatar */}
              <div className="md:hidden w-9 h-9 rounded-full bg-gradient-to-br from-brand-green/30 to-brand-green-dark/30 border border-brand-green/30 flex items-center justify-center text-brand-green font-bold text-sm">
                {user?.first_name?.[0]?.toUpperCase() || "U"}
              </div>
            </div>
          </div>
        </div>

        {/* Page Content */}
        <div className="p-6 md:p-10 max-w-6xl">
          {children}
        </div>
      </main>
    </div>
  );
}
