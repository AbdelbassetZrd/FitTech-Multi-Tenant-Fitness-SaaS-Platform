"use client";

import React, { useState } from "react";
import { Subscription, adminCancelSubscriptionApi } from "@/lib/api";
import { useAuthStore } from "@/lib/stores/authStore";

interface CancelSubscriptionModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
  subscription: Subscription | null;
}

const CONSEQUENCES = [
  "Loss of 24/7 Priority Support",
  "Deletion of historical performance logs",
  "Termination of active API keys",
];

export default function CancelSubscriptionModal({ isOpen, onClose, onSuccess, subscription }: CancelSubscriptionModalProps) {
  const accessToken = useAuthStore((s) => s.accessToken);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  if (!isOpen || !subscription) return null;

  const handleCancel = async () => {
    if (!accessToken) return;
    setError("");
    setLoading(true);
    try {
      await adminCancelSubscriptionApi(subscription.id, accessToken);
      onSuccess();
      onClose();
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Failed to cancel subscription.");
    } finally {
      setLoading(false);
    }
  };

  const planName = subscription.plan?.name || "Unknown";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
      <div className="relative w-full max-w-md bg-[#0F172A] border border-white/10 rounded-2xl shadow-2xl overflow-hidden animate-fade-in-up">
        <div className="h-1 w-full bg-gradient-to-r from-red-500 via-red-400 to-red-500" />
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-24 bg-red-500/15 blur-[100px] pointer-events-none" />

        <div className="p-8 relative">
          {/* Warning Icon */}
          <div className="flex justify-center mb-6">
            <div className="w-16 h-16 rounded-2xl bg-red-500/10 border border-red-500/20 flex items-center justify-center">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-8 h-8 text-red-400">
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
              </svg>
            </div>
          </div>

          <h2 className="text-2xl font-black text-white text-center mb-3">Terminate Subscription</h2>
          <p className="text-sm text-text-muted text-center leading-relaxed mb-6">
            Warning: Terminating your {planName} subscription will result in{" "}
            <span className="text-white font-bold">immediate loss of access</span> to all analytics data,
            security vaults, and active infrastructure nodes. This action is permanent.
          </p>

          {error && (
            <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm font-medium text-center">{error}</div>
          )}

          <div className="space-y-3 mb-8">
            {CONSEQUENCES.map((item, i) => (
              <div key={i} className="flex items-center gap-3 px-4 py-3.5 bg-red-500/5 border border-red-500/10 rounded-xl">
                <div className="w-5 h-5 rounded-full bg-red-500/20 flex items-center justify-center shrink-0">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2.5} stroke="currentColor" className="w-3 h-3 text-red-400">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </div>
                <span className="text-sm text-red-200/70">{item}</span>
              </div>
            ))}
          </div>

          <div className="space-y-3">
            <button onClick={onClose} className="w-full px-6 py-3.5 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-black tracking-wider uppercase transition-all duration-300 hover:shadow-[0_0_20px_rgba(46,204,112,0.3)]">
              Keep Plan
            </button>
            <button onClick={handleCancel} disabled={loading} className="w-full px-6 py-3.5 bg-white/5 hover:bg-red-500/10 border border-white/10 hover:border-red-500/30 text-white/70 hover:text-red-400 rounded-xl text-sm font-bold tracking-wider uppercase transition-all duration-300 disabled:opacity-40">
              {loading ? "Cancelling..." : "Cancel Anyway"}
            </button>
          </div>

          <div className="flex items-center justify-center gap-2 mt-6">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.8} stroke="currentColor" className="w-3.5 h-3.5 text-white/20">
              <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
            </svg>
            <span className="text-[10px] font-bold tracking-[0.15em] text-white/20 uppercase">Secure Termination Portal</span>
          </div>
        </div>
      </div>
    </div>
  );
}
