"use client";

import React, { useState, useEffect, useRef, useCallback } from "react";
import AdminHeader from "@/components/admin/AdminHeader";
import { useAuthStore } from "@/lib/stores/authStore";
import {
  assignNFCDeviceApi,
  deactivateNFCDeviceApi,
  listNFCDevicesApi,
  NFCDevice,
} from "@/lib/api";

export default function SettingsPage() {
  const user = useAuthStore((s) => s.user);
  const accessToken = useAuthStore((s) => s.accessToken);

  // ── NFC Cards ────────────────────────────────────────────────────────────
  const [nfcCards, setNfcCards] = useState<NFCDevice[]>([]);
  const [nfcLoading, setNfcLoading] = useState(false);
  const [nfcError, setNfcError] = useState("");
  const [nfcSuccess, setNfcSuccess] = useState("");
  const [nfcScanning, setNfcScanning] = useState(false);
  const [newUid, setNewUid] = useState("");
  const [newDeviceType, setNewDeviceType] = useState("card");
  const nfcPollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const stopNfcCapture = useCallback(() => {
    setNfcScanning(false);
    if (nfcPollRef.current) { clearInterval(nfcPollRef.current); nfcPollRef.current = null; }
  }, []);

  const startNfcCapture = useCallback(() => {
    setNfcScanning(true);
    setNewUid("");
    nfcPollRef.current = setInterval(async () => {
      try {
        const backendUrl = process.env.NEXT_PUBLIC_API_BASE_URL || "https://providing-april-manger.ngrok-free.dev";
        const res = await fetch(`${backendUrl}/api/access/capture-uid/?session_id=default`,
          { headers: { "ngrok-skip-browser-warning": "true", "Accept": "application/json" } });
        const data = await res.json();
        if (data.uid) { setNewUid(data.uid); stopNfcCapture(); }
      } catch (_) {}
    }, 1000);
  }, [stopNfcCapture]);

  useEffect(() => () => stopNfcCapture(), [stopNfcCapture]);

  const fetchAdminCards = useCallback(async () => {
    if (!accessToken) return;
    try {
      const data = await listNFCDevicesApi(accessToken, 'admin');
      setNfcCards(data.results.filter(d => d.is_active));
    } catch (_) {}
  }, [accessToken]);

  useEffect(() => { fetchAdminCards(); }, [fetchAdminCards]);

  const handleAssignCard = async () => {
    if (!accessToken || !user || !newUid.trim()) return;
    setNfcLoading(true); setNfcError(""); setNfcSuccess("");
    try {
      await assignNFCDeviceApi(
        { user_id: String(user.id), uid: newUid.trim(), device_type: newDeviceType, role: "admin" },
        accessToken,
      );
      setNfcSuccess(`Card ${newUid} added successfully.`);
      setNewUid("");
      await fetchAdminCards();
    } catch (err: any) {
      setNfcError(err?.data?.error || err?.message || "Failed to add card");
    } finally {
      setNfcLoading(false);
    }
  };

  const handleDeactivate = async (uid: string) => {
    if (!accessToken) return;
    setNfcError(""); setNfcSuccess("");
    try {
      await deactivateNFCDeviceApi(uid, accessToken);
      setNfcSuccess(`Card ${uid} deactivated.`);
      await fetchAdminCards();
    } catch (err: any) {
      setNfcError(err?.data?.error || err?.message || "Failed to deactivate");
    }
  };

  // States for Security and Notifications
  const [twoFactorAuth, setTwoFactorAuth] = useState(true);
  const [sessionAlerts, setSessionAlerts] = useState(true);
  const [systemIntegrity, setSystemIntegrity] = useState(true);
  const [marketingDigests, setMarketingDigests] = useState(false);
  const [billingReports, setBillingReports] = useState(true);

  return (
    <>
      <AdminHeader />

      <div className="p-6 md:p-8 space-y-8 animate-fade-in-up">
        {/* Header Area */}
        <div>
          <p className="text-[10px] font-bold tracking-[0.2em] text-brand-green uppercase mb-2">Admin Settings</p>
          <h1 className="text-3xl font-black text-white">System Architecture</h1>
          <p className="text-sm text-text-muted mt-2 max-w-3xl">
            Configure your administrative profile, security protocols, and system communication preferences for Emerald Gym.
          </p>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Account Profile Card */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6 relative overflow-hidden">
            <div className="absolute top-0 right-0 p-4">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5 text-text-muted/30">
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
              </svg>
            </div>
            
            <div className="flex items-center gap-2 text-white mb-6">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-brand-green">
                <path fillRule="evenodd" d="M7.5 6a4.5 4.5 0 119 0 4.5 4.5 0 01-9 0zM3.751 20.105a8.25 8.25 0 0116.498 0 .75.75 0 01-.437.695A18.683 18.683 0 0112 22.5c-2.786 0-5.433-.608-7.812-1.7a.75.75 0 01-.437-.695z" clipRule="evenodd" />
              </svg>
              <h2 className="text-lg font-bold">Account Profile</h2>
            </div>

            <div className="flex items-center gap-6 mb-8">
              <div className="relative">
                <div className="w-20 h-20 rounded-xl bg-gradient-to-br from-brand-green/20 to-brand-green-dark/20 border-2 border-brand-green/30 flex items-center justify-center text-brand-green font-bold text-2xl">
                  {user?.first_name?.[0]?.toUpperCase() || "A"}
                </div>
                <button className="absolute -bottom-2 -right-2 bg-brand-green text-[#0B1120] p-1.5 rounded-lg hover:bg-brand-green-light transition-colors shadow-lg">
                  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" className="w-4 h-4">
                    <path d="M2.695 14.763l-1.262 3.152a.5.5 0 00.65.65l3.151-1.262a4 4 0 001.343-.885L17.5 5.5a2.121 2.121 0 00-3-3L3.58 13.42a4 4 0 00-.885 1.343z" />
                  </svg>
                </button>
              </div>
              
              <div>
                <p className="text-[10px] font-bold tracking-widest text-text-muted/60 uppercase mb-1">Status</p>
                <div className="flex items-center gap-2">
                  <span className="w-2 h-2 rounded-full bg-brand-green shadow-[0_0_8px_rgba(46,204,112,0.6)]" />
                  <span className="text-brand-green font-bold text-sm tracking-wide">ACTIVE ARCHITECT</span>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold tracking-wider text-text-muted uppercase ml-1">Full Name</label>
                <input 
                  type="text" 
                  defaultValue={`${user?.first_name || 'Alexander'} ${user?.last_name || 'Sterling'}`}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-all"
                />
              </div>
              <div className="space-y-1.5">
                <label className="text-[10px] font-bold tracking-wider text-text-muted uppercase ml-1">Email Address</label>
                <input 
                  type="email" 
                  defaultValue={user?.email || 'alexander@fit-tech.com'}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-all"
                />
              </div>
            </div>

            <div className="flex justify-end">
              <button className="px-6 py-2.5 bg-white/5 hover:bg-brand-green hover:text-[#0B1120] text-brand-green rounded-xl text-sm font-bold transition-all duration-300 border border-brand-green/30 hover:border-transparent">
                SAVE CHANGES
              </button>
            </div>
          </div>

          {/* Security Card */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6 relative overflow-hidden">
            <div className="absolute top-0 right-0 p-4">
               <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5 text-text-muted/30">
                 <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
               </svg>
            </div>
            
            <div className="flex items-center gap-2 text-white mb-6">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-brand-green">
                <path fillRule="evenodd" d="M12 1.5a5.25 5.25 0 00-5.25 5.25v3a3 3 0 00-3 3v6.75a3 3 0 003 3h10.5a3 3 0 003-3v-6.75a3 3 0 00-3-3v-3c0-2.9-2.35-5.25-5.25-5.25zm3.75 8.25v-3a3.75 3.75 0 10-7.5 0v3h7.5z" clipRule="evenodd" />
              </svg>
              <h2 className="text-lg font-bold">Security</h2>
            </div>

            <div className="space-y-4 mb-6">
              <div>
                <div className="flex justify-between items-center mb-1.5">
                  <label className="text-[10px] font-bold tracking-wider text-text-muted uppercase ml-1">Change Password</label>
                  <span className="text-[10px] text-text-muted/50 uppercase font-medium">Last changed 14d ago</span>
                </div>
                <div className="relative cursor-pointer group">
                  <input 
                    type="password" 
                    defaultValue="••••••••••••"
                    readOnly
                    className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white focus:outline-none group-hover:bg-white/10 transition-all cursor-pointer pointer-events-none"
                  />
                  <div className="absolute right-4 top-1/2 -translate-y-1/2 text-text-muted group-hover:text-white transition-colors">
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
                    </svg>
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-white/5 border border-brand-green/20 rounded-xl p-4 flex items-center justify-between mb-6">
              <div className="flex items-start gap-3">
                <div className="mt-0.5 p-1.5 bg-brand-green/20 rounded-lg text-brand-green">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M10.5 1.5H8.25A2.25 2.25 0 006 3.75v16.5a2.25 2.25 0 002.25 2.25h7.5A2.25 2.25 0 0018 20.25V3.75a2.25 2.25 0 00-2.25-2.25H13.5m-3 0V3h3V1.5m-3 0h3m-3 18.75h3" />
                  </svg>
                </div>
                <div>
                  <p className="text-sm font-bold text-white mb-0.5">Two-Factor Auth</p>
                  <p className="text-[11px] text-text-muted">Mobile authentication active</p>
                </div>
              </div>
              
              <button 
                onClick={() => setTwoFactorAuth(!twoFactorAuth)}
                className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${twoFactorAuth ? 'bg-brand-green' : 'bg-white/10'}`}
              >
                <span className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${twoFactorAuth ? 'translate-x-6' : 'translate-x-1'}`} />
              </button>
            </div>

            <button className="w-full px-6 py-3 bg-white/5 hover:bg-white/10 text-white rounded-xl text-sm font-bold transition-all duration-300 border border-white/10 uppercase tracking-wide">
              Manage Auth Devices
            </button>
          </div>

          {/* Notifications Card */}
          <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6 relative overflow-hidden">
            <div className="absolute top-0 right-0 p-4">
               <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5 text-text-muted/30">
                 <path strokeLinecap="round" strokeLinejoin="round" d="M14.857 17.082a23.848 23.848 0 005.454-1.31A8.967 8.967 0 0118 9.75v-.7V9A6 6 0 006 9v.75a8.967 8.967 0 01-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 01-5.714 0m5.714 0a3 3 0 11-5.714 0" />
               </svg>
            </div>
            
            <div className="flex items-center gap-2 text-white mb-6">
              <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" className="w-5 h-5 text-brand-green">
                <path fillRule="evenodd" d="M5.25 9a6.75 6.75 0 0113.5 0v.75c0 2.123.8 4.057 2.118 5.52a.75.75 0 01-.297 1.206c-1.544.57-3.16.99-4.831 1.243a3.75 3.75 0 11-7.48 0 24.585 24.585 0 01-4.831-1.244.75.75 0 01-.298-1.205A8.217 8.217 0 005.25 9.75V9zm4.502 8.9a2.25 2.25 0 104.496 0 25.057 25.057 0 01-4.496 0z" clipRule="evenodd" />
              </svg>
              <h2 className="text-lg font-bold">Notifications</h2>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-y-6 gap-x-8">
              <div className="flex justify-between items-start gap-4">
                <div>
                  <p className="text-sm font-bold text-white mb-1">Session Alerts</p>
                  <p className="text-[11px] text-text-muted leading-relaxed">Instant alerts for missed coach sessions.</p>
                </div>
                <button 
                  onClick={() => setSessionAlerts(!sessionAlerts)}
                  className={`relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors ${sessionAlerts ? 'bg-brand-green' : 'bg-white/10'}`}
                >
                  <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${sessionAlerts ? 'translate-x-5' : 'translate-x-1'}`} />
                </button>
              </div>

              <div className="flex justify-between items-start gap-4">
                <div>
                  <p className="text-sm font-bold text-white mb-1">System Integrity</p>
                  <p className="text-[11px] text-text-muted leading-relaxed">Security breaches and server status.</p>
                </div>
                <button 
                  onClick={() => setSystemIntegrity(!systemIntegrity)}
                  className={`relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors ${systemIntegrity ? 'bg-brand-green' : 'bg-white/10'}`}
                >
                  <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${systemIntegrity ? 'translate-x-5' : 'translate-x-1'}`} />
                </button>
              </div>

              <div className="flex justify-between items-start gap-4">
                <div>
                  <p className="text-sm font-bold text-white mb-1">Marketing Digests</p>
                  <p className="text-[11px] text-text-muted leading-relaxed">Weekly fitness tips and gym news.</p>
                </div>
                <button 
                  onClick={() => setMarketingDigests(!marketingDigests)}
                  className={`relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors ${marketingDigests ? 'bg-brand-green' : 'bg-white/10'}`}
                >
                  <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${marketingDigests ? 'translate-x-5' : 'translate-x-1'}`} />
                </button>
              </div>

              <div className="flex justify-between items-start gap-4">
                <div>
                  <p className="text-sm font-bold text-white mb-1">Billing Reports</p>
                  <p className="text-[11px] text-text-muted leading-relaxed">Monthly subscription cycle updates.</p>
                </div>
                <button 
                  onClick={() => setBillingReports(!billingReports)}
                  className={`relative inline-flex h-5 w-9 shrink-0 items-center rounded-full transition-colors ${billingReports ? 'bg-brand-green' : 'bg-white/10'}`}
                >
                  <span className={`inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform ${billingReports ? 'translate-x-5' : 'translate-x-1'}`} />
                </button>
              </div>
            </div>
          </div>

          {/* Terminate Session Card */}
          <div className="bg-gradient-to-br from-red-500/5 to-red-900/10 border border-red-500/10 rounded-2xl p-6 relative overflow-hidden flex flex-col items-center justify-center text-center">
            <div className="w-16 h-16 rounded-full bg-red-500/10 flex items-center justify-center mb-4">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-8 h-8 text-red-500">
                <path strokeLinecap="round" strokeLinejoin="round" d="M5.636 5.636a9 9 0 1012.728 0M12 3v9" />
              </svg>
            </div>
            
            <h2 className="text-xl font-bold text-white mb-2">Terminate Session</h2>
            <p className="text-sm text-text-muted max-w-[250px] mb-6">
              Securely sign out of the Performance Architect console and clear local cache.
            </p>
            
            <button className="px-8 py-3 bg-red-500 hover:bg-red-400 text-white rounded-xl text-sm font-bold transition-all duration-300 shadow-lg shadow-red-500/20 uppercase tracking-wider">
              Sign Out
            </button>
          </div>

        </div>

        <div className="pt-8 border-t border-white/5 flex flex-col md:flex-row items-center justify-between gap-4">
          <p className="text-[10px] font-bold tracking-widest text-text-muted/40 uppercase">
            FitTech Version 4.2.0-Alpha
          </p>
          <div className="flex gap-6 text-[10px] font-bold tracking-widest text-text-muted/40 uppercase">
            <a href="#" className="hover:text-white transition-colors">Privacy Policy</a>
            <a href="#" className="hover:text-white transition-colors">Terms of Service</a>
            <a href="#" className="hover:text-white transition-colors">Help Center</a>
          </div>
        </div>

        {/* NFC Access Cards */}
        <div className="bg-[#111827]/80 border border-white/5 rounded-2xl p-6">
          <div className="flex items-center gap-2 text-white mb-6">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5 text-brand-green">
              <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z" />
            </svg>
            <h2 className="text-lg font-bold">My NFC Access Cards</h2>
            <span className="ml-auto text-[10px] font-bold tracking-wider text-text-muted/50 bg-white/5 px-2 py-1 rounded-md">{nfcCards.length} ACTIVE</span>
          </div>

          {/* Feedback */}
          {nfcError && (
            <div className="mb-4 p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm">{nfcError}</div>
          )}
          {nfcSuccess && (
            <div className="mb-4 p-3 rounded-xl bg-brand-green/10 border border-brand-green/20 text-brand-green text-sm">{nfcSuccess}</div>
          )}

          {/* Add new card */}
          <div className="bg-white/[0.02] border border-white/[0.06] rounded-xl p-4 mb-5 space-y-3">
            <p className="text-[10px] font-bold text-text-muted/50 uppercase tracking-[0.15em]">Register New Card</p>
            <div className="flex gap-2">
              {!nfcScanning ? (
                <button type="button" onClick={startNfcCapture}
                  className="flex items-center gap-2 px-4 py-2 rounded-lg bg-brand-green/15 border border-brand-green/30 text-brand-green text-xs font-bold hover:bg-brand-green/25 transition-all">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z" />
                  </svg>
                  Scan Card
                </button>
              ) : (
                <button type="button" onClick={stopNfcCapture}
                  className="flex items-center gap-2 px-4 py-2 rounded-lg bg-yellow-500/10 border border-yellow-500/30 text-yellow-400 text-xs font-bold hover:bg-yellow-500/20 transition-all">
                  <span className="w-2 h-2 rounded-full bg-yellow-400 animate-pulse" />
                  Waiting for card… (cancel)
                </button>
              )}
            </div>
            <div className="flex gap-3">
              <div className="relative flex-1">
                <input type="text" value={newUid}
                  onChange={(e) => setNewUid(e.target.value.toUpperCase())}
                  placeholder={nfcScanning ? "Tap card on reader…" : "UID — auto-filled on scan or type manually"}
                  className={`w-full bg-white/5 border rounded-xl px-4 py-2.5 text-sm text-white placeholder-white/20 focus:outline-none transition-all font-mono tracking-wider ${
                    nfcScanning ? "border-yellow-500/40" : newUid ? "border-brand-green/40" : "border-white/10 focus:border-brand-green/40"
                  }`} />
                {newUid && (
                  <button type="button" onClick={() => setNewUid("")}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-white/30 hover:text-white">
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-3.5 h-3.5"><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>
                )}
              </div>
              <button onClick={handleAssignCard} disabled={!newUid.trim() || nfcLoading}
                className="px-5 py-2.5 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-bold transition-all disabled:opacity-40 disabled:cursor-not-allowed whitespace-nowrap">
                {nfcLoading ? "Adding…" : "Add Card"}
              </button>
            </div>
            <div className="flex gap-2">
              {(["card", "phone"] as const).map((t) => (
                <button key={t} type="button" onClick={() => setNewDeviceType(t)}
                  className={`flex-1 py-1.5 rounded-lg text-xs font-bold transition-all border ${
                    newDeviceType === t ? "bg-brand-green/15 border-brand-green/40 text-brand-green" : "bg-white/[0.03] border-white/10 text-white/40 hover:border-white/20"
                  }`}>
                  {t === "card" ? "🪪  Physical Card" : "📱  Phone NFC"}
                </button>
              ))}
            </div>
          </div>

          {/* Active cards list */}
          {nfcCards.length === 0 ? (
            <p className="text-sm text-text-muted/50 text-center py-6">No active NFC cards registered for your account.</p>
          ) : (
            <div className="space-y-2">
              {nfcCards.map((card) => (
                <div key={card.id} className="flex items-center justify-between bg-white/[0.03] border border-white/[0.06] rounded-xl px-4 py-3">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-lg bg-brand-green/10 border border-brand-green/20 flex items-center justify-center">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-4 h-4 text-brand-green">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 3v1.5M4.5 8.25H3m18 0h-1.5M4.5 12H3m18 0h-1.5m-15 3.75H3m18 0h-1.5M8.25 19.5V21M12 3v1.5m0 15V21m3.75-18v1.5m0 15V21m-9-1.5h10.5a2.25 2.25 0 002.25-2.25V6.75a2.25 2.25 0 00-2.25-2.25H6.75A2.25 2.25 0 004.5 6.75v10.5a2.25 2.25 0 002.25 2.25zm.75-12h9v9h-9v-9z" />
                      </svg>
                    </div>
                    <div>
                      <p className="text-sm font-mono font-bold text-white tracking-wider">{card.uid}</p>
                      <p className="text-[11px] text-text-muted/50 capitalize">{card.device_type} · added {new Date(card.created_at).toLocaleDateString()}</p>
                    </div>
                  </div>
                  <button onClick={() => handleDeactivate(card.uid)}
                    className="p-2 rounded-lg text-text-muted/40 hover:text-red-400 hover:bg-red-500/10 transition-all" title="Remove card">
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                    </svg>
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </>
  );
}
