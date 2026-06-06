"use client";

import React, { useState } from "react";

interface AddEquipmentModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (payload: { name: string; category: string; status: string }) => Promise<void>;
}

export default function AddEquipmentModal({ isOpen, onClose, onSave }: AddEquipmentModalProps) {
  const [name, setName] = useState("");
  const [category, setCategory] = useState("");
  const [status, setStatus] = useState("active");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  if (!isOpen) return null;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !category.trim()) {
      setError("Name and category are required.");
      return;
    }
    setSaving(true);
    setError("");
    try {
      await onSave({ name: name.trim(), category: category.trim(), status });
      setName("");
      setCategory("");
      setStatus("active");
      onClose();
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "Failed to add equipment.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onClose} />
      <div className="relative w-full max-w-md bg-[#0B1120] border border-white/10 rounded-2xl shadow-2xl p-6 overflow-hidden animate-fade-in-up">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-24 blur-[100px] pointer-events-none bg-brand-green/20" />

        <div className="flex justify-between items-start mb-6 relative">
          <div>
            <h2 className="text-xl font-black text-white">Add New Equipment</h2>
            <p className="text-sm text-text-muted mt-1">Register a new equipment item to the inventory.</p>
          </div>
          <button onClick={onClose} className="p-2 text-white/50 hover:text-white hover:bg-white/10 rounded-xl transition-colors ml-4 shrink-0">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {error && (
          <div className="mb-4 p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm font-medium relative">{error}</div>
        )}

        <form onSubmit={handleSubmit} className="space-y-4 relative">
          <div>
            <label className="block text-xs font-bold text-text-muted uppercase tracking-wider mb-1.5">Equipment Name *</label>
            <input
              type="text" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Treadmill Pro X500"
              className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-text-muted/40 text-sm focus:outline-none focus:border-brand-green/50 focus:ring-1 focus:ring-brand-green/30 transition-all"
            />
          </div>
          <div>
            <label className="block text-xs font-bold text-text-muted uppercase tracking-wider mb-1.5">Category *</label>
            <input
              type="text" value={category} onChange={(e) => setCategory(e.target.value)} placeholder="e.g. Cardio, Weights, Accessories"
              className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white placeholder-text-muted/40 text-sm focus:outline-none focus:border-brand-green/50 focus:ring-1 focus:ring-brand-green/30 transition-all"
            />
          </div>
          <div>
            <label className="block text-xs font-bold text-text-muted uppercase tracking-wider mb-1.5">Initial Status</label>
            <select
              value={status} onChange={(e) => setStatus(e.target.value)}
              className="w-full px-4 py-3 rounded-xl bg-white/5 border border-white/10 text-white text-sm focus:outline-none focus:border-brand-green/50 focus:ring-1 focus:ring-brand-green/30 transition-all appearance-none cursor-pointer"
            >
              <option value="active" className="bg-[#0B1120]">Active</option>
              <option value="under_repair" className="bg-[#0B1120]">Under Repair</option>
              <option value="out_of_order" className="bg-[#0B1120]">Out of Order</option>
            </select>
          </div>

          <div className="pt-4 flex justify-end gap-3 border-t border-white/5 mt-6">
            <button type="button" onClick={onClose} className="px-6 py-2.5 rounded-xl text-sm font-bold text-white hover:bg-white/5 transition-all">CANCEL</button>
            <button type="submit" disabled={saving}
              className="px-6 py-2.5 rounded-xl text-sm font-bold bg-brand-green hover:bg-brand-green-light text-[#0B1120] transition-all hover:shadow-lg hover:shadow-brand-green/20 disabled:opacity-50"
            >
              {saving ? "ADDING..." : "ADD EQUIPMENT"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
