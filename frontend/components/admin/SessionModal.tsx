import React, { useState, useEffect } from "react";
import { Session, Course, getAdminCoursesApi } from "@/lib/api";
import { useAuthStore } from "@/lib/stores/authStore";

interface SessionModalProps {
  isOpen: boolean;
  onClose: () => void;
  session?: Session | null;
  onSave: (payload: any) => Promise<void>;
}

export default function SessionModal({ isOpen, onClose, session, onSave }: SessionModalProps) {
  const accessToken = useAuthStore((state) => state.accessToken);
  const [courses, setCourses] = useState<Course[]>([]);
  const [loadingCourses, setLoadingCourses] = useState(false);

  const [formData, setFormData] = useState({
    course: 0,
    date: "",
    duration_time: 60,
    salle_fk: 0,
    notes: "",
  });
  
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (isOpen && accessToken && courses.length === 0) {
      setLoadingCourses(true);
      getAdminCoursesApi(accessToken)
        .then(setCourses)
        .catch(() => {})
        .finally(() => setLoadingCourses(false));
    }
  }, [isOpen, accessToken, courses.length]);

  useEffect(() => {
    if (session) {
      setFormData({
        course: session.course || 0,
        date: session.date || "",
        duration_time: session.duration_time || 60,
        salle_fk: session.salle_fk || 0,
        notes: session.notes || "",
      });
    } else {
      setFormData({
        course: 0,
        date: new Date().toISOString().split('T')[0],
        duration_time: 60,
        salle_fk: 0,
        notes: "",
      });
    }
  }, [session, isOpen]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: type === "number" || name === "course" || name === "salle_fk" ? parseInt(value) || 0 : value,
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.course) {
      setError("Please select a course.");
      return;
    }
    setError("");
    setLoading(true);
    try {
      const payload: any = { ...formData };
      if (!payload.salle_fk) delete payload.salle_fk;
      await onSave(payload);
      onClose();
    } catch (err: any) {
      setError(err?.data?.error || err?.message || "An error occurred");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity" onClick={onClose} />
      
      {/* Modal */}
      <div className="relative w-full max-w-xl bg-[#0B1120] border border-white/10 rounded-2xl shadow-2xl p-6 overflow-hidden animate-fade-in-up md:p-8">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-24 bg-brand-green/20 blur-[100px] pointer-events-none" />

        <div className="flex justify-between items-center mb-6 relative">
          <div>
            <h2 className="text-2xl font-black text-white">{session ? "Edit Session" : "Create New Session"}</h2>
            <p className="text-sm text-text-muted mt-1">{session ? "Update session schedule and details." : "Schedule a new course session."}</p>
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
          <div className="space-y-1.5">
            <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Course</label>
            <select name="course" value={formData.course} onChange={handleChange} required disabled={!!session}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors appearance-none disabled:opacity-50">
              <option value={0} disabled className="bg-[#111827]">Select Course</option>
              {loadingCourses ? (
                <option disabled className="bg-[#111827]">Loading courses...</option>
              ) : (
                courses.map(c => (
                  <option key={c.id} value={c.id} className="bg-[#111827]">
                    {c.name} ({c.day} at {c.time.substring(0, 5)}) - Coach: {c.coach_name}
                  </option>
                ))
              )}
            </select>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Date</label>
              <input required type="date" name="date" value={formData.date} onChange={handleChange}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors" />
            </div>
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Duration (mins)</label>
              <input required type="number" name="duration_time" value={formData.duration_time} onChange={handleChange} min="15" step="15"
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors" />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Room (Salle ID) Optional</label>
            <input type="number" name="salle_fk" value={formData.salle_fk || ""} onChange={handleChange} placeholder="e.g. 1" min="1"
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors" />
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Notes (Optional)</label>
            <textarea name="notes" value={formData.notes} onChange={handleChange} rows={2}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors resize-none"
              placeholder="Any special instructions..." />
          </div>

          <div className="pt-4 flex justify-end gap-3 border-t border-white/5 mt-6">
            <button type="button" onClick={onClose}
              className="px-6 py-2.5 rounded-xl text-sm font-bold text-white hover:bg-white/5 transition-all">
              CANCEL
            </button>
            <button type="submit" disabled={loading}
              className="px-6 py-2.5 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-black tracking-wider transition-all hover:shadow-[0_0_20px_rgba(46,204,112,0.4)] disabled:opacity-50">
              {loading ? "SAVING..." : (session ? "SAVE CHANGES" : "CREATE SESSION")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
