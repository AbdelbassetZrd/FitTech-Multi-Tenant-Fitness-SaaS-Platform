import React, { useState, useEffect } from "react";
import { SubscriptionPlan } from "@/lib/api";

interface SubscriptionPlanModalProps {
  isOpen: boolean;
  onClose: () => void;
  plan?: SubscriptionPlan | null;
  onSave: (payload: any) => Promise<void>;
}

export default function SubscriptionPlanModal({ isOpen, onClose, plan, onSave }: SubscriptionPlanModalProps) {
  const [formData, setFormData] = useState({
    name: "",
    plan_type: "monthly",
    price: "",
    times_per_week: 7,
    duration_days: 30,
    session_count: 0,
    description: "",
    is_active: true,
    is_featured: false,
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (plan) {
      setFormData({
        name: plan.name || "",
        plan_type: plan.plan_type || "monthly",
        price: plan.price || "",
        times_per_week: plan.times_per_week ?? 7,
        duration_days: plan.duration_days ?? 30,
        session_count: plan.session_count ?? 0,
        description: plan.description || "",
        is_active: plan.is_active ?? true,
        is_featured: plan.is_featured ?? false,
      });
    } else {
      setFormData({
        name: "",
        plan_type: "monthly",
        price: "",
        times_per_week: 7,
        duration_days: 30,
        session_count: 0,
        description: "",
        is_active: true,
        is_featured: false,
      });
    }
    setError("");
  }, [plan, isOpen]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target;
    if (type === "checkbox") {
      const checked = (e.target as HTMLInputElement).checked;
      setFormData((prev) => ({ ...prev, [name]: checked }));
    } else if (type === "number") {
      setFormData((prev) => ({ ...prev, [name]: parseFloat(value) || 0 }));
    } else {
      setFormData((prev) => ({ ...prev, [name]: value }));
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.name.trim()) {
      setError("Plan name is required.");
      return;
    }
    if (!formData.price || parseFloat(formData.price) <= 0) {
      setError("Price must be greater than 0.");
      return;
    }
    setError("");
    setLoading(true);
    try {
      const payload: any = { ...formData };
      // Clean optional fields based on plan type
      if (payload.plan_type === "per_session") {
        delete payload.duration_days;
      } else {
        delete payload.session_count;
      }
      await onSave(payload);
      onClose();
    } catch (err: any) {
      setError(err?.data?.error || err?.data?.detail || err?.message || "An error occurred");
    } finally {
      setLoading(false);
    }
  };

  const showDuration = formData.plan_type !== "per_session";
  const showSessionCount = formData.plan_type === "per_session";

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity" onClick={onClose} />

      {/* Modal */}
      <div className="relative w-full max-w-xl bg-[#0B1120] border border-white/10 rounded-2xl shadow-2xl p-6 overflow-hidden animate-fade-in-up md:p-8 max-h-[90vh] overflow-y-auto">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-24 bg-brand-green/20 blur-[100px] pointer-events-none" />

        <div className="flex justify-between items-center mb-6 relative">
          <div>
            <h2 className="text-2xl font-black text-white">{plan ? "Edit Plan" : "Create New Plan"}</h2>
            <p className="text-sm text-text-muted mt-1">{plan ? "Update subscription plan details." : "Configure a new subscription plan."}</p>
          </div>
          <button onClick={onClose} className="p-2 text-white/50 hover:text-white hover:bg-white/10 rounded-xl transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        {error && (
          <div className="mb-6 p-4 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-sm font-medium">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5 relative">
          {/* Name */}
          <div className="space-y-1.5">
            <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Plan Name</label>
            <input
              required
              type="text"
              name="name"
              value={formData.name}
              onChange={handleChange}
              placeholder="e.g. Elite Membership"
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
            />
          </div>

          {/* Plan Type + Price */}
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Plan Type</label>
              <select
                name="plan_type"
                value={formData.plan_type}
                onChange={handleChange}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors appearance-none"
              >
                <option value="monthly" className="bg-[#111827]">Monthly</option>
                <option value="annual" className="bg-[#111827]">Annual</option>
                <option value="per_session" className="bg-[#111827]">Per Session</option>
                <option value="free_trial" className="bg-[#111827]">Free Trial</option>
              </select>
            </div>
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Price (DA)</label>
              <input
                required
                type="number"
                name="price"
                value={formData.price}
                onChange={handleChange}
                min="0"
                step="0.01"
                placeholder="0.00"
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
              />
            </div>
          </div>

          {/* Times per Week + Duration/Sessions */}
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Times/Week</label>
              <input
                type="number"
                name="times_per_week"
                value={formData.times_per_week}
                onChange={handleChange}
                min="1"
                max="7"
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
              />
            </div>
            {showDuration && (
              <div className="space-y-1.5">
                <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Duration (Days)</label>
                <input
                  type="number"
                  name="duration_days"
                  value={formData.duration_days}
                  onChange={handleChange}
                  min="1"
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
                />
              </div>
            )}
            {showSessionCount && (
              <div className="space-y-1.5">
                <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Session Count</label>
                <input
                  type="number"
                  name="session_count"
                  value={formData.session_count}
                  onChange={handleChange}
                  min="1"
                  className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
                />
              </div>
            )}
          </div>

          {/* Description */}
          <div className="space-y-1.5">
            <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Description</label>
            <textarea
              name="description"
              value={formData.description}
              onChange={handleChange}
              rows={3}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors resize-none"
              placeholder="Plan features and benefits..."
            />
          </div>

          {/* Toggles */}
          <div className="flex items-center gap-6">
            <label className="flex items-center gap-2.5 cursor-pointer group">
              <input
                type="checkbox"
                name="is_active"
                checked={formData.is_active}
                onChange={handleChange}
                className="sr-only peer"
              />
              <div className="w-9 h-5 bg-white/10 rounded-full peer-checked:bg-brand-green/80 transition-colors relative after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:w-4 after:h-4 after:bg-white after:rounded-full after:transition-transform peer-checked:after:translate-x-4" />
              <span className="text-sm text-text-muted group-hover:text-white transition-colors">Active</span>
            </label>
            <label className="flex items-center gap-2.5 cursor-pointer group">
              <input
                type="checkbox"
                name="is_featured"
                checked={formData.is_featured}
                onChange={handleChange}
                className="sr-only peer"
              />
              <div className="w-9 h-5 bg-white/10 rounded-full peer-checked:bg-amber-500/80 transition-colors relative after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:w-4 after:h-4 after:bg-white after:rounded-full after:transition-transform peer-checked:after:translate-x-4" />
              <span className="text-sm text-text-muted group-hover:text-white transition-colors">Featured</span>
            </label>
          </div>

          <div className="pt-4 flex justify-end gap-3 border-t border-white/5 mt-6">
            <button type="button" onClick={onClose}
              className="px-6 py-2.5 rounded-xl text-sm font-bold text-white hover:bg-white/5 transition-all">
              CANCEL
            </button>
            <button type="submit" disabled={loading}
              className="px-6 py-2.5 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-black tracking-wider transition-all hover:shadow-[0_0_20px_rgba(46,204,112,0.4)] disabled:opacity-50">
              {loading ? "SAVING..." : (plan ? "SAVE CHANGES" : "CREATE PLAN")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
