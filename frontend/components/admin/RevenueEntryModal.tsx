"use client";

import React, { useState, useEffect, useRef } from "react";
import { User, searchAdminMembersApi, adminCreateManualPaymentApi } from "@/lib/api";
import { useAuthStore } from "@/lib/stores/authStore";

interface RevenueEntryModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export default function RevenueEntryModal({ isOpen, onClose, onSuccess }: RevenueEntryModalProps) {
  const accessToken = useAuthStore((s) => s.accessToken);
  const [mode, setMode] = useState<"member" | "guest">("member");
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<User[]>([]);
  const [selectedMember, setSelectedMember] = useState<User | null>(null);
  const [searching, setSearching] = useState(false);
  const [showDropdown, setShowDropdown] = useState(false);
  const [paymentMethod, setPaymentMethod] = useState("cash");
  const [category, setCategory] = useState("subscription");
  const [amount, setAmount] = useState("");
  const [currency, setCurrency] = useState("DZD");
  const [note, setNote] = useState("");
  const [guestName, setGuestName] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [successTx, setSuccessTx] = useState("");

  const searchRef = useRef<HTMLDivElement>(null);
  const searchTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!searchQuery.trim() || !accessToken || mode !== "member") {
      setSearchResults([]);
      setShowDropdown(false);
      return;
    }
    if (searchTimeout.current) clearTimeout(searchTimeout.current);
    searchTimeout.current = setTimeout(async () => {
      setSearching(true);
      try {
        const results = await searchAdminMembersApi(searchQuery, accessToken);
        setSearchResults(results);
        setShowDropdown(true);
      } catch { setSearchResults([]); }
      finally { setSearching(false); }
    }, 300);
    return () => { if (searchTimeout.current) clearTimeout(searchTimeout.current); };
  }, [searchQuery, accessToken, mode]);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) setShowDropdown(false);
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  useEffect(() => {
    if (!isOpen) {
      setMode("member"); setSearchQuery(""); setSearchResults([]); setSelectedMember(null);
      setPaymentMethod("cash"); setCategory("subscription"); setAmount(""); setCurrency("DZD");
      setNote(""); setGuestName(""); setError(""); setSuccessTx("");
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleSelectMember = (m: User) => {
    setSelectedMember(m);
    setSearchQuery(m.full_name || `${m.first_name} ${m.last_name}`);
    setShowDropdown(false);
  };

  const handleSubmit = async () => {
    if (!amount || parseFloat(amount) <= 0) { setError("Enter a valid amount."); return; }
    if (mode === "member" && !selectedMember) { setError("Select a member."); return; }
    if (!accessToken) return;

    setError(""); setLoading(true);
    try {
      const res = await adminCreateManualPaymentApi({
        user_id: mode === "member" && selectedMember ? selectedMember.id : undefined,
        amount: parseFloat(amount),
        payment_method: paymentMethod,
        category,
        currency,
        note,
        guest_name: mode === "guest" ? guestName : undefined,
      }, accessToken);
      setSuccessTx(res.transaction_id);
      onSuccess();
      setTimeout(() => onClose(), 2000);
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Failed to record payment.");
    } finally { setLoading(false); }
  };

  const txIdPreview = `TX_ID: ${Math.random().toString(36).substring(2, 6).toUpperCase()}-FF-SLATE`;

  if (successTx) {
    return (
      <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
        <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
        <div className="relative w-full max-w-md bg-[#0F172A] border border-brand-green/30 rounded-2xl shadow-2xl p-8 text-center animate-fade-in-up">
          <div className="w-16 h-16 rounded-full bg-brand-green/20 flex items-center justify-center mx-auto mb-4">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-8 h-8 text-brand-green">
              <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
            </svg>
          </div>
          <h3 className="text-xl font-black text-white mb-2">Payment Confirmed</h3>
          <p className="text-sm text-text-muted mb-4">Transaction recorded successfully.</p>
          <p className="text-[11px] font-mono text-brand-green bg-brand-green/10 px-4 py-2 rounded-lg inline-block">{successTx}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
      <div className="relative w-full max-w-lg bg-[#0B1222] border border-white/10 rounded-2xl shadow-2xl overflow-hidden animate-fade-in-up max-h-[90vh] overflow-y-auto">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-24 bg-brand-green/10 blur-[100px] pointer-events-none" />

        <div className="p-8 relative">
          <button onClick={onClose} className="absolute top-6 right-6 p-2 text-white/40 hover:text-white hover:bg-white/10 rounded-xl transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          <h2 className="text-2xl font-black text-white mb-1">Revenue Entry</h2>
          <p className="text-[10px] font-bold tracking-[0.2em] text-white/30 uppercase mb-6">Manual Transaction Override</p>

          {/* Mode Toggle */}
          <div className="flex bg-white/5 rounded-xl p-1 mb-6">
            {(["member", "guest"] as const).map((m) => (
              <button key={m} onClick={() => { setMode(m); setSelectedMember(null); setSearchQuery(""); }}
                className={`flex-1 py-2.5 rounded-lg text-sm font-bold transition-all ${mode === m ? "bg-brand-green text-[#0B1120]" : "text-text-muted hover:text-white"}`}>
                {m === "member" ? "Member Search" : "Walk-in Guest"}
              </button>
            ))}
          </div>

          {error && (
            <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm font-medium">{error}</div>
          )}

          {/* Customer Identification */}
          <div className="mb-5">
            <label className="text-[11px] font-bold tracking-[0.15em] text-white/50 uppercase mb-2 block">Customer Identification</label>
            {mode === "member" ? (
              <div ref={searchRef} className="relative">
                <div className="relative">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4 text-white/30 absolute left-4 top-1/2 -translate-y-1/2">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
                  </svg>
                  <input type="text" value={searchQuery}
                    onChange={(e) => { setSearchQuery(e.target.value); if (selectedMember) setSelectedMember(null); }}
                    placeholder="Search by name, ID or email..."
                    className="w-full bg-white/5 border border-white/10 rounded-xl pl-10 pr-4 py-3.5 text-white placeholder-white/25 focus:outline-none focus:border-brand-green/50 transition-colors" />
                </div>
                {showDropdown && searchResults.length > 0 && (
                  <div className="absolute z-10 w-full mt-2 bg-[#111827] border border-white/10 rounded-xl overflow-hidden shadow-2xl max-h-40 overflow-y-auto">
                    {searchResults.map((m) => (
                      <button key={m.id} onClick={() => handleSelectMember(m)}
                        className="w-full flex items-center gap-3 px-4 py-3 hover:bg-white/5 transition-colors text-left">
                        <div className="w-7 h-7 rounded-full bg-brand-green/20 flex items-center justify-center text-brand-green text-[10px] font-bold">
                          {(m.full_name || m.first_name || "?")[0].toUpperCase()}
                        </div>
                        <div>
                          <p className="text-sm font-semibold text-white">{m.full_name || `${m.first_name} ${m.last_name}`}</p>
                          <p className="text-[10px] text-text-muted">{m.email}</p>
                        </div>
                      </button>
                    ))}
                  </div>
                )}
                {searching && (
                  <div className="absolute z-10 w-full mt-2 bg-[#111827] border border-white/10 rounded-xl p-3 text-center">
                    <div className="w-5 h-5 rounded-full border-2 border-brand-green/20 border-t-brand-green animate-spin mx-auto" />
                  </div>
                )}
              </div>
            ) : (
              <input type="text" value={guestName} onChange={(e) => setGuestName(e.target.value)}
                placeholder="Guest name (optional)..."
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3.5 text-white placeholder-white/25 focus:outline-none focus:border-brand-green/50 transition-colors" />
            )}
          </div>

          {/* Transaction Type & Category */}
          <div className="grid grid-cols-2 gap-4 mb-5">
            <div>
              <label className="text-[11px] font-bold tracking-[0.15em] text-white/50 uppercase mb-2 block">Transaction Type</label>
              <select value={paymentMethod} onChange={(e) => setPaymentMethod(e.target.value)}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3.5 text-white focus:outline-none focus:border-brand-green/50 transition-colors appearance-none">
                <option value="cash" className="bg-[#111827]">Cash</option>
                <option value="card" className="bg-[#111827]">Card</option>
                <option value="mobile" className="bg-[#111827]">Mobile Payment</option>
              </select>
            </div>
            <div>
              <label className="text-[11px] font-bold tracking-[0.15em] text-white/50 uppercase mb-2 block">Category</label>
              <div className="relative">
                <select value={category} onChange={(e) => setCategory(e.target.value)}
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3.5 text-white focus:outline-none focus:border-brand-green/50 transition-colors appearance-none">
                  <option value="subscription" className="bg-[#111827]">Subscription</option>
                  <option value="session" className="bg-[#111827]">Session</option>
                  <option value="product" className="bg-[#111827]">Product</option>
                  <option value="other" className="bg-[#111827]">Other</option>
                </select>
              </div>
            </div>
          </div>

          {/* Revenue Amount */}
          <div className="mb-5">
            <label className="text-[11px] font-bold tracking-[0.15em] text-white/50 uppercase mb-2 block">Revenue Amount</label>
            <div className="flex gap-3">
              <div className="relative flex-1">
                <span className="absolute left-4 top-1/2 -translate-y-1/2 text-brand-green font-bold text-sm">DA</span>
                <input type="number" value={amount} onChange={(e) => setAmount(e.target.value)} min="0" step="0.01" placeholder="0.00"
                  className="w-full bg-white/5 border border-white/10 rounded-xl pl-12 pr-4 py-3.5 text-white placeholder-white/25 focus:outline-none focus:border-brand-green/50 transition-colors text-lg font-bold" />
              </div>
              <select value={currency} onChange={(e) => setCurrency(e.target.value)}
                className="bg-white/5 border border-white/10 rounded-xl px-4 py-3.5 text-white focus:outline-none focus:border-brand-green/50 transition-colors appearance-none w-24">
                <option value="DZD" className="bg-[#111827]">DZD</option>
                <option value="USD" className="bg-[#111827]">USD</option>
                <option value="EUR" className="bg-[#111827]">EUR</option>
              </select>
            </div>
          </div>

          {/* Internal Audit Note */}
          <div className="mb-8">
            <label className="text-[11px] font-bold tracking-[0.15em] text-white/50 uppercase mb-2 block">Internal Audit Note</label>
            <textarea value={note} onChange={(e) => setNote(e.target.value)} rows={3} placeholder="Add specific details for finance audit..."
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3.5 text-white placeholder-white/25 focus:outline-none focus:border-brand-green/50 transition-colors resize-none" />
          </div>

          {/* Confirm Button */}
          <button onClick={handleSubmit} disabled={loading}
            className="w-full flex items-center justify-center gap-3 px-6 py-4 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-black tracking-widest uppercase transition-all duration-300 hover:shadow-[0_0_30px_rgba(46,204,112,0.3)] disabled:opacity-40">
            {loading ? (
              <><div className="w-4 h-4 rounded-full border-2 border-[#0B1120]/30 border-t-[#0B1120] animate-spin" />Processing...</>
            ) : (
              <><svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor" className="w-4 h-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M4.5 12.75l6 6 9-13.5" />
              </svg>Confirm Entry</>
            )}
          </button>

          {/* Footer */}
          <p className="text-center text-[10px] text-white/15 mt-4 font-bold tracking-[0.1em] uppercase">
            Validated by Performance Architect Protocol
          </p>
          <div className="flex items-center justify-between mt-3 px-2">
            <div className="flex items-center gap-1.5">
              <div className="w-2 h-2 rounded-full bg-brand-green animate-pulse" />
              <span className="text-[10px] font-bold text-white/20 uppercase">System Secure</span>
            </div>
            <span className="text-[10px] font-mono text-white/15">{txIdPreview}</span>
          </div>
        </div>
      </div>
    </div>
  );
}
