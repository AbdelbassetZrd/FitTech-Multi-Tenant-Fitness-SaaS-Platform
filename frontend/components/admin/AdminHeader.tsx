"use client";

import { useAuthStore } from "@/lib/stores/authStore";
import { useState, useRef, useEffect } from "react";
import { useRouter, usePathname } from "next/navigation";
import { getAdminNotificationsApi } from "@/lib/api";

interface AdminHeaderProps {
  searchPlaceholder?: string;
  searchQuery?: string;
  onSearchChange?: (val: string) => void;
  actionLabel?: string;
  onActionClick?: () => void;
}

export default function AdminHeader({
  searchPlaceholder = "Search members, activities, or records...",
  searchQuery = "",
  onSearchChange,
  actionLabel,
  onActionClick,
}: AdminHeaderProps) {
  const user = useAuthStore((s) => s.user);
  const logout = useAuthStore((s) => s.logout);
  const token = useAuthStore((s) => s.accessToken);
  const router = useRouter();
  const pathname = usePathname() || "";
  
  const [hasUnread, setHasUnread] = useState(false);

  useEffect(() => {
    if (!token) return;
    getAdminNotificationsApi(token)
      .then(data => setHasUnread(data.some(n => !n.is_read)))
      .catch(console.error);
  }, [token, pathname]); // Re-fetch when pathname changes to stay updated
  
  const showSearch = pathname.includes("/admin/members") || pathname.includes("/admin/coaches") || pathname.includes("/admin/equipment");
  
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  const menuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        setIsMenuOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  const handleLogout = async () => {
    await logout();
    router.push("/admin/login");
  };

  const handleMockAction = (actionName: string) => {
    alert(`${actionName} feature is coming soon!`);
  };

  const [localSearch, setLocalSearch] = useState("");
  const isControlled = onSearchChange !== undefined;

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (isControlled) {
      onSearchChange(e.target.value);
    } else {
      setLocalSearch(e.target.value);
    }
  };

  const currentSearchValue = isControlled ? searchQuery : localSearch;

  return (
    <div className="sticky top-0 z-20 bg-[#0f1726]/90 backdrop-blur-xl border-b border-white/5">
      <div className="px-6 md:px-8 py-3.5 flex items-center justify-between gap-4">
        {/* Search Bar - Only shown on specific pages */}
        {showSearch ? (
          <div className="flex-1 max-w-xl">
            <div className="relative">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-text-muted/50">
                <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
              </svg>
              <input
                type="text"
                value={currentSearchValue}
                onChange={handleSearchChange}
                placeholder={searchPlaceholder}
                className="w-full bg-white/5 border border-white/5 rounded-xl pl-10 pr-4 py-2.5 text-sm text-white placeholder-text-muted/40 focus:outline-none focus:border-brand-green/30 focus:bg-white/8 transition-all duration-300"
              />
            </div>
          </div>
        ) : (
          <div className="flex-1" />
        )}

        {/* Right Actions */}
        <div className="flex items-center gap-3">
          {/* Optional Action Button */}
          {actionLabel && onActionClick && (
            <button 
              onClick={onActionClick}
              className="hidden md:flex items-center gap-2 px-4 py-2 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-bold transition-all duration-300"
            >
              {actionLabel}
            </button>
          )}

          {/* Notification Bell */}
          <button 
            onClick={() => router.push("/admin/notifications")}
            className="relative p-2 rounded-lg hover:bg-white/5 transition-colors text-text-muted/70 hover:text-white"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0" />
            </svg>
            {hasUnread && (
              <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-brand-green rounded-full" />
            )}
          </button>

          {/* Help */}
          <button 
            onClick={() => router.push("/admin/messages")}
            className="p-2 rounded-lg hover:bg-white/5 transition-colors text-text-muted/70 hover:text-white"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z" />
            </svg>
          </button>

          {/* Support link */}
          <button onClick={() => router.push("/admin/messages")} className="hidden lg:block text-sm text-text-muted/60 font-medium hover:text-white transition-colors">Support</button>

          <div className="relative" ref={menuRef}>
            {/* User Avatar */}
            <div 
              onClick={() => setIsMenuOpen(!isMenuOpen)}
              className="w-9 h-9 rounded-full bg-gradient-to-br from-brand-green/30 to-brand-green-dark/30 border border-brand-green/30 flex items-center justify-center text-brand-green font-bold text-sm cursor-pointer hover:border-brand-green/60 transition-all"
            >
              {user?.first_name?.[0]?.toUpperCase() || "A"}
            </div>

            {/* Dropdown Menu */}
            {isMenuOpen && (
              <div className="absolute right-0 mt-3 w-48 bg-[#111827] border border-white/10 rounded-xl shadow-xl overflow-hidden py-1 animate-fade-in-up z-50">
                <div className="px-4 py-2 mb-1 border-b border-white/5 xl:hidden">
                  <p className="text-sm font-semibold text-white truncate">{user?.first_name || "Admin"} {user?.last_name || ""}</p>
                  <p className="text-[10px] text-text-muted uppercase tracking-wider">{user?.role || "System Admin"}</p>
                </div>
                <button 
                  onClick={() => { setIsMenuOpen(false); router.push("/admin/settings"); }}
                  className="w-full text-left px-4 py-2 text-sm text-text-muted hover:text-white hover:bg-white/5 transition-colors"
                >
                  Profile
                </button>
                <button 
                  onClick={() => { setIsMenuOpen(false); router.push("/admin/settings"); }}
                  className="w-full text-left px-4 py-2 text-sm text-text-muted hover:text-white hover:bg-white/5 transition-colors"
                >
                  Settings
                </button>
                <button 
                  onClick={handleLogout}
                  className="w-full text-left px-4 py-2 text-sm text-red-400 hover:text-red-300 hover:bg-red-400/10 transition-colors border-t border-white/5 mt-1 pt-2"
                >
                  Logout
                </button>
              </div>
            )}
          </div>

          {/* User info (desktop) */}
          <div className="hidden xl:block">
            <p className="text-sm font-semibold text-white leading-tight">{user?.first_name || "Marcus"} {user?.last_name || "Vane"}</p>
            <p className="text-[10px] text-text-muted uppercase tracking-wider">{user?.role || "System Admin"}</p>
          </div>
        </div>
      </div>
    </div>
  );
}
