"use client";

import React, { useState, useEffect, useRef } from "react";
import {
  SubscriptionPlan,
  User,
  getAdminPlansApi,
  searchAdminMembersApi,
  adminCreateSubscriptionApi,
} from "@/lib/api";
import { useAuthStore } from "@/lib/stores/authStore";

interface CreateSubscriptionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

/* ── Plan tier icons ─────────────────────────────────────────────────── */
function TierIcon({ tier }: { tier: string }) {
  const lower = tier.toLowerCase();
  if (lower.includes("elite") || lower.includes("premium"))
    return (
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5">
        <path strokeLinecap="round" strokeLinejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" />
      </svg>
    );
  if (lower.includes("pro") || lower.includes("full"))
    return (
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5">
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
      </svg>
    );
  return (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5">
      <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
    </svg>
  );
}

function getPlanDescription(plan: SubscriptionPlan): string {
  const name = plan.name.toLowerCase();
  if (name.includes("elite") || name.includes("premium")) return "ALL-INCLUSIVE COACHING";
  if (name.includes("pro") || name.includes("full")) return "FULL ACCESS + RECOVERY";
  return "ESSENTIAL GYM ACCESS";
}

export default function CreateSubscriptionModal({
  isOpen,
  onClose,
  onSuccess,
}: CreateSubscriptionModalProps) {
  const accessToken = useAuthStore((s) => s.accessToken);

  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [selectedPlan, setSelectedPlan] = useState<SubscriptionPlan | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [searchResults, setSearchResults] = useState<User[]>([]);
  const [selectedMember, setSelectedMember] = useState<User | null>(null);
  const [searching, setSearching] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [showDropdown, setShowDropdown] = useState(false);

  const searchRef = useRef<HTMLDivElement>(null);
  const searchTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);

  /* ── Fetch plans ──────────────────────────────────────────────────── */
  useEffect(() => {
    if (!isOpen || !accessToken) return;
    getAdminPlansApi(accessToken)
      .then((data) => setPlans(data.filter((p) => p.is_active)))
      .catch(() => {});
  }, [isOpen, accessToken]);

  /* ── Debounced member search ──────────────────────────────────────── */
  useEffect(() => {
    if (!searchQuery.trim() || !accessToken) {
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
      } catch {
        setSearchResults([]);
      } finally {
        setSearching(false);
      }
    }, 300);
    return () => { if (searchTimeout.current) clearTimeout(searchTimeout.current); };
  }, [searchQuery, accessToken]);

  /* ── Click outside to close dropdown ─────────────────────────────── */
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) {
        setShowDropdown(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  /* ── Reset on close ──────────────────────────────────────────────── */
  useEffect(() => {
    if (!isOpen) {
      setSelectedPlan(null);
      setSelectedMember(null);
      setSearchQuery("");
      setSearchResults([]);
      setError("");
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const handleSelectMember = (member: User) => {
    setSelectedMember(member);
    setSearchQuery(member.full_name || `${member.first_name} ${member.last_name}`);
    setShowDropdown(false);
  };

  const handleSubmit = async () => {
    if (!selectedMember) {
      setError("Please select a member.");
      return;
    }
    if (!selectedPlan) {
      setError("Please select a plan.");
      return;
    }
    if (!accessToken) return;

    setError("");
    setLoading(true);
    try {
      await adminCreateSubscriptionApi(
        { user_id: selectedMember.id, plan_id: selectedPlan.id },
        accessToken,
      );
      onSuccess();
      onClose();
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Failed to create subscription.");
    } finally {
      setLoading(false);
    }
  };

  // Sort plans by price for display
  const sortedPlans = [...plans].sort(
    (a, b) => parseFloat(a.price) - parseFloat(b.price),
  );

  // Find the featured / recommended plan
  const recommendedPlan = sortedPlans.find((p) => p.is_featured);

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />

      {/* Modal */}
      <div className="relative w-full max-w-lg bg-[#0F172A] border border-white/10 rounded-2xl shadow-2xl overflow-hidden animate-fade-in-up max-h-[90vh] overflow-y-auto">
        {/* Green glow */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-24 bg-brand-green/15 blur-[100px] pointer-events-none" />

        <div className="p-8 relative">
          {/* Close button */}
          <button
            onClick={onClose}
            className="absolute top-6 right-6 p-2 text-white/40 hover:text-white hover:bg-white/10 rounded-xl transition-colors"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          {/* Header */}
          <p className="text-[10px] font-bold tracking-[0.2em] text-brand-green uppercase mb-1">
            Subscription Protocol
          </p>
          <h2 className="text-2xl font-black text-white mb-8">New Subscription</h2>

          {/* Error */}
          {error && (
            <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm font-medium">
              {error}
            </div>
          )}

          {/* Member Identity Section */}
          <div className="mb-8">
            <label className="flex items-center gap-2 text-[11px] font-bold tracking-[0.15em] text-white/50 uppercase mb-3">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
              </svg>
              Member Identity
            </label>
            <div ref={searchRef} className="relative">
              <div className="relative">
                <input
                  type="text"
                  value={searchQuery}
                  onChange={(e) => {
                    setSearchQuery(e.target.value);
                    if (selectedMember) setSelectedMember(null);
                  }}
                  placeholder="Search by name or UUID..."
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3.5 text-white placeholder-white/25 focus:outline-none focus:border-brand-green/50 focus:bg-white/[0.07] transition-colors pr-16"
                />
                <span className="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] font-bold text-white/20 bg-white/5 px-2 py-1 rounded-md">
                  CMD+K
                </span>
              </div>

              {/* Dropdown */}
              {showDropdown && searchResults.length > 0 && (
                <div className="absolute z-10 w-full mt-2 bg-[#111827] border border-white/10 rounded-xl overflow-hidden shadow-2xl max-h-48 overflow-y-auto">
                  {searchResults.map((m) => (
                    <button
                      key={m.id}
                      onClick={() => handleSelectMember(m)}
                      className="w-full flex items-center gap-3 px-4 py-3 hover:bg-white/5 transition-colors text-left"
                    >
                      <div className="w-8 h-8 rounded-full bg-gradient-to-br from-brand-green/30 to-brand-green-dark/10 flex items-center justify-center text-brand-green text-xs font-bold shrink-0">
                        {(m.full_name || m.first_name || "?")[0].toUpperCase()}
                      </div>
                      <div>
                        <p className="text-sm font-semibold text-white">
                          {m.full_name || `${m.first_name} ${m.last_name}`}
                        </p>
                        <p className="text-[10px] text-text-muted">{m.email}</p>
                      </div>
                    </button>
                  ))}
                </div>
              )}

              {searching && (
                <div className="absolute z-10 w-full mt-2 bg-[#111827] border border-white/10 rounded-xl p-4 text-center">
                  <div className="w-5 h-5 rounded-full border-2 border-brand-green/20 border-t-brand-green animate-spin mx-auto" />
                </div>
              )}
            </div>

            {/* Selected member badge */}
            {selectedMember && (
              <div className="mt-3 flex items-center gap-2 px-3 py-2 bg-brand-green/10 border border-brand-green/20 rounded-lg">
                <div className="w-6 h-6 rounded-full bg-brand-green/20 flex items-center justify-center text-brand-green text-[10px] font-bold">
                  ✓
                </div>
                <span className="text-sm text-brand-green font-semibold">
                  {selectedMember.full_name || `${selectedMember.first_name} ${selectedMember.last_name}`}
                </span>
                <span className="text-[10px] text-brand-green/60 ml-auto">ID: #{selectedMember.id}</span>
              </div>
            )}
          </div>

          {/* Select Performance Tier */}
          <div className="mb-8">
            <label className="flex items-center gap-2 text-[11px] font-bold tracking-[0.15em] text-white/50 uppercase mb-3">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-4 h-4">
                <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
              </svg>
              Select Performance Tier
            </label>
            <div className="space-y-3">
              {sortedPlans.map((plan) => {
                const isSelected = selectedPlan?.id === plan.id;
                const isRecommended = recommendedPlan?.id === plan.id;
                return (
                  <button
                    key={plan.id}
                    onClick={() => setSelectedPlan(plan)}
                    className={`relative w-full flex items-center gap-4 px-5 py-4 rounded-xl border transition-all duration-300 text-left ${
                      isSelected
                        ? "bg-brand-green/10 border-brand-green/60 shadow-[0_0_20px_rgba(46,204,112,0.1)]"
                        : "bg-white/[0.03] border-white/10 hover:border-white/20 hover:bg-white/[0.05]"
                    }`}
                  >
                    {/* Recommended badge */}
                    {isRecommended && (
                      <span className="absolute -top-2.5 right-4 text-[8px] font-black tracking-widest text-[#0B1120] bg-brand-green px-2.5 py-0.5 rounded-md uppercase">
                        Recommended
                      </span>
                    )}

                    {/* Icon */}
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${
                      isSelected
                        ? "bg-brand-green/20 text-brand-green"
                        : "bg-white/5 text-white/40"
                    }`}>
                      <TierIcon tier={plan.name} />
                    </div>

                    {/* Info */}
                    <div className="flex-1 min-w-0">
                      <p className={`font-bold ${isSelected ? "text-white" : "text-white/80"}`}>
                        {plan.name}
                      </p>
                      <p className="text-[10px] text-white/30 uppercase tracking-wider">
                        {getPlanDescription(plan)}
                      </p>
                    </div>

                    {/* Price */}
                    <div className="text-right shrink-0">
                      <p className={`text-lg font-black ${isSelected ? "text-white" : "text-white/70"}`}>
                        {parseFloat(plan.price).toLocaleString()} DA
                      </p>
                      <p className="text-[10px] text-white/30 uppercase">/ month</p>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Initial Billing */}
          {selectedPlan && (
            <div className="flex items-center justify-between px-1 mb-8">
              <span className="text-[11px] font-bold tracking-[0.15em] text-white/50 uppercase">
                Initial Billing
              </span>
              <div className="flex items-baseline gap-1">
                <span className="text-2xl font-black text-white">
                  {parseFloat(selectedPlan.price).toLocaleString()} DA
                </span>
                <span className="text-xs text-white/30 font-bold">DZD</span>
              </div>
            </div>
          )}

          {/* Confirm Button */}
          <button
            onClick={handleSubmit}
            disabled={loading || !selectedMember || !selectedPlan}
            className="w-full flex items-center justify-center gap-3 px-6 py-4 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-black tracking-widest uppercase transition-all duration-300 hover:shadow-[0_0_30px_rgba(46,204,112,0.3)] disabled:opacity-40 disabled:hover:shadow-none"
          >
            {loading ? (
              <>
                <div className="w-4 h-4 rounded-full border-2 border-[#0B1120]/30 border-t-[#0B1120] animate-spin" />
                Processing...
              </>
            ) : (
              <>
                Confirm Subscription
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor" className="w-4 h-4">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" />
                </svg>
              </>
            )}
          </button>

          {/* Disclaimer */}
          <p className="text-center text-[10px] text-white/20 mt-4 leading-relaxed">
            By confirming, you authorize immediate activation of the selected tier for the selected
            member identity. All billing cycles reset to today&apos;s date.
          </p>
        </div>
      </div>
    </div>
  );
}
