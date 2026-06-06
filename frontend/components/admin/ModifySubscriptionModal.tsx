"use client";

import React, { useState, useEffect } from "react";
import {
  SubscriptionPlan,
  Subscription,
  getAdminPlansApi,
  adminUpdateSubscriptionPlanApi,
} from "@/lib/api";
import { useAuthStore } from "@/lib/stores/authStore";

interface ModifySubscriptionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  subscription: Subscription | null;
}

/* ── Tier icons (same as create modal) ───────────────────────────────── */
function TierIcon({ tier, className }: { tier: string; className?: string }) {
  const lower = tier.toLowerCase();
  if (lower.includes("elite") || lower.includes("premium"))
    return (
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className={className || "w-5 h-5"}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M11.48 3.499a.562.562 0 011.04 0l2.125 5.111a.563.563 0 00.475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 00-.182.557l1.285 5.385a.562.562 0 01-.84.61l-4.725-2.885a.563.563 0 00-.586 0L6.982 20.54a.562.562 0 01-.84-.61l1.285-5.386a.562.562 0 00-.182-.557l-4.204-3.602a.563.563 0 01.321-.988l5.518-.442a.563.563 0 00.475-.345L11.48 3.5z" />
      </svg>
    );
  if (lower.includes("pro") || lower.includes("full"))
    return (
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className={className || "w-5 h-5"}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M3.75 13.5l10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75z" />
      </svg>
    );
  return (
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className={className || "w-5 h-5"}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904L9 18.75l-.813-2.846a4.5 4.5 0 00-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 003.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 003.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 00-3.09 3.09z" />
    </svg>
  );
}

function getPlanSubtitle(plan: SubscriptionPlan): string {
  const name = plan.name.toLowerCase();
  if (name.includes("elite") || name.includes("premium")) return "Predictive AI & unlimited seats";
  if (name.includes("pro") || name.includes("full")) return "Full API access & 5 user seats";
  return "Core analytics & 1 user seat";
}

export default function ModifySubscriptionModal({
  isOpen,
  onClose,
  onSuccess,
  subscription,
}: ModifySubscriptionModalProps) {
  const accessToken = useAuthStore((s) => s.accessToken);

  const [plans, setPlans] = useState<SubscriptionPlan[]>([]);
  const [selectedPlanId, setSelectedPlanId] = useState<number | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const currentPlan = subscription?.plan;
  const currentPrice = currentPlan ? parseFloat(currentPlan.price) : 0;

  /* ── Fetch plans ──────────────────────────────────────────────────── */
  useEffect(() => {
    if (!isOpen || !accessToken) return;
    getAdminPlansApi(accessToken)
      .then((data) => setPlans(data.filter((p) => p.is_active)))
      .catch(() => {});
  }, [isOpen, accessToken]);

  /* ── Reset on close ──────────────────────────────────────────────── */
  useEffect(() => {
    if (!isOpen) {
      setSelectedPlanId(null);
      setError("");
    } else if (currentPlan) {
      setSelectedPlanId(currentPlan.id);
    }
  }, [isOpen, currentPlan]);

  if (!isOpen || !subscription) return null;

  const sortedPlans = [...plans].sort(
    (a, b) => parseFloat(a.price) - parseFloat(b.price),
  );

  const handleSubmit = async () => {
    if (!selectedPlanId || selectedPlanId === currentPlan?.id) {
      setError("Please select a different plan.");
      return;
    }
    if (!accessToken) return;

    setError("");
    setLoading(true);
    try {
      await adminUpdateSubscriptionPlanApi(subscription.id, { plan_id: selectedPlanId }, accessToken);
      onSuccess();
      onClose();
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Failed to update subscription.");
    } finally {
      setLoading(false);
    }
  };

  const memberName = subscription.user_name || "Unknown Member";
  const memberInitials = memberName
    .split(" ")
    .map((n) => n[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />

      {/* Modal */}
      <div className="relative w-full max-w-lg bg-[#0F172A] border border-white/10 rounded-2xl shadow-2xl overflow-hidden animate-fade-in-up max-h-[90vh] overflow-y-auto">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-24 bg-brand-green/15 blur-[100px] pointer-events-none" />

        <div className="p-8 relative">
          {/* Close */}
          <button
            onClick={onClose}
            className="absolute top-6 right-6 p-2 text-white/40 hover:text-white hover:bg-white/10 rounded-xl transition-colors"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          {/* Header */}
          <h2 className="text-2xl font-black text-white mb-1">Update Subscription</h2>
          <p className="text-sm text-text-muted mb-8">Adjust member access levels and billing cycle</p>

          {/* Error */}
          {error && (
            <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm font-medium">
              {error}
            </div>
          )}

          {/* Member Info Card */}
          <div className="flex items-center gap-4 mb-8 px-5 py-4 bg-white/[0.03] border border-white/10 rounded-xl">
            <div className="w-12 h-12 rounded-full bg-gradient-to-br from-brand-green/30 to-blue-500/20 flex items-center justify-center text-white font-bold text-sm shrink-0">
              {memberInitials}
            </div>
            <div className="flex-1 min-w-0">
              <p className="font-bold text-white text-sm">{memberName}</p>
              <p className="text-[10px] text-text-muted">
                ID: #MS-{String(subscription.id).padStart(5, "0")} • Member since{" "}
                {new Date(subscription.created_at).toLocaleDateString("en-US", {
                  month: "short",
                  year: "numeric",
                })}
              </p>
            </div>
            {currentPlan && (
              <span className="text-[9px] font-black tracking-widest text-brand-green bg-brand-green/10 border border-brand-green/20 px-3 py-1.5 rounded-lg uppercase shrink-0">
                Current Plan: {currentPlan.name}
              </span>
            )}
          </div>

          {/* Select New Tier */}
          <div className="mb-6">
            <label className="text-[11px] font-bold tracking-[0.15em] text-white/50 uppercase mb-3 block">
              Select New Tier
            </label>
            <div className="space-y-3">
              {sortedPlans.map((plan) => {
                const planPrice = parseFloat(plan.price);
                const delta = planPrice - currentPrice;
                const isCurrent = plan.id === currentPlan?.id;
                const isSelected = plan.id === selectedPlanId;

                return (
                  <button
                    key={plan.id}
                    onClick={() => setSelectedPlanId(plan.id)}
                    className={`relative w-full flex items-center gap-4 px-5 py-4 rounded-xl border transition-all duration-300 text-left ${
                      isSelected
                        ? "bg-brand-green/10 border-brand-green/60 shadow-[0_0_20px_rgba(46,204,112,0.1)]"
                        : "bg-white/[0.03] border-white/10 hover:border-white/20 hover:bg-white/[0.05]"
                    }`}
                  >
                    {/* Active badge for current plan */}
                    {isCurrent && (
                      <span className="absolute -top-2.5 left-4 text-[8px] font-black tracking-widest text-[#0B1120] bg-brand-green px-2.5 py-0.5 rounded-md uppercase">
                        Active
                      </span>
                    )}

                    {/* Icon */}
                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center shrink-0 ${
                      isSelected || isCurrent
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
                      <p className="text-[10px] text-white/30">
                        {getPlanSubtitle(plan)}
                      </p>
                    </div>

                    {/* Price delta */}
                    <div className="text-right shrink-0">
                      {isCurrent ? (
                        <>
                          <p className="text-lg font-black text-white">
                            {planPrice.toLocaleString()} DA
                          </p>
                          <p className="text-[10px] text-white/30 uppercase">Current Billing</p>
                        </>
                      ) : (
                        <>
                          <p className={`text-lg font-black ${
                            delta > 0 ? "text-amber-400" : "text-brand-green"
                          }`}>
                            {delta > 0 ? "+" : ""}{delta.toLocaleString()} DA
                          </p>
                          <p className="text-[10px] text-white/30 uppercase">Per Month</p>
                        </>
                      )}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Info Notice */}
          <div className="flex gap-3 px-4 py-3.5 bg-amber-500/5 border border-amber-500/10 rounded-xl mb-8">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-5 h-5 text-amber-400 shrink-0 mt-0.5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853l.041-.021M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9-3.75h.008v.008H12V8.25z" />
            </svg>
            <p className="text-[11px] text-amber-200/60 leading-relaxed">
              Upgrades are applied immediately. Downgrades will take effect at the end of the
              current billing cycle ({subscription.end_date
                ? new Date(subscription.end_date + "T00:00:00").toLocaleDateString("en-US", {
                    month: "short",
                    day: "numeric",
                    year: "numeric",
                  })
                : "N/A"}
              ). A pro-rated credit will be applied to the next invoice.
            </p>
          </div>

          {/* Action buttons */}
          <div className="flex items-center justify-end gap-3">
            <button
              onClick={onClose}
              className="px-6 py-3 rounded-xl text-sm font-bold text-white hover:bg-white/5 transition-all"
            >
              Cancel
            </button>
            <button
              onClick={handleSubmit}
              disabled={loading || !selectedPlanId || selectedPlanId === currentPlan?.id}
              className="px-8 py-3 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-black tracking-wider uppercase transition-all duration-300 hover:shadow-[0_0_20px_rgba(46,204,112,0.3)] disabled:opacity-40"
            >
              {loading ? "Updating..." : "Update Plan"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
