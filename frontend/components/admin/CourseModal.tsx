import React, { useState, useEffect } from "react";
import { Course, CoachProfile, getAdminCoachesApi, getAdminSallesApi, getRoomsAvailabilityApi } from "@/lib/api";
import { useAuthStore } from "@/lib/stores/authStore";

interface CourseModalProps {
  isOpen: boolean;
  onClose: () => void;
  course?: Course | null;
  onSave: (payload: any) => Promise<void>;
}

const WEEK_DAYS = [
  { code: 'MON', label: 'Monday' },
  { code: 'TUE', label: 'Tuesday' },
  { code: 'WED', label: 'Wednesday' },
  { code: 'THU', label: 'Thursday' },
  { code: 'FRI', label: 'Friday' },
  { code: 'SAT', label: 'Saturday' },
  { code: 'SUN', label: 'Sunday' },
];

export default function CourseModal({ isOpen, onClose, course, onSave }: CourseModalProps) {
  const accessToken = useAuthStore((s) => s.accessToken);
  const [coaches, setCoaches] = useState<CoachProfile[]>([]);
  const [loadingCoaches, setLoadingCoaches] = useState(false);
  const [salles, setSalles] = useState<{ id: number; name: string; capacity?: number }[]>([]);
  const [loadingSalles, setLoadingSalles] = useState(false);
  const [roomAvailability, setRoomAvailability] = useState<Record<number, { is_available: boolean; reason?: string }>>({});

  const [formData, setFormData] = useState({
    name: "",
    coach: "",
    day: "MON",
    days: [] as string[],
    time: "09:00",
    max_members: 10,
    number_of_sessions: 4,
    session_price: "",
    salle: "",
  });

  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    if (isOpen && accessToken && coaches.length === 0) {
      setLoadingCoaches(true);
      getAdminCoachesApi(accessToken)
        .then(setCoaches)
        .catch(() => {})
        .finally(() => setLoadingCoaches(false));
    }
    if (isOpen && accessToken && salles.length === 0) {
      setLoadingSalles(true);
      getAdminSallesApi(accessToken)
        .then(setSalles)
        .catch(() => {})
        .finally(() => setLoadingSalles(false));
    }
  }, [isOpen, accessToken, coaches.length]);

  useEffect(() => {
    if (course) {
      setFormData({
        name: course.name || "",
        coach: course.coach ? String(course.coach) : "",
        day: course.day || "MON",
        days: course.day ? [course.day] : [],
        time: course.time ? course.time.substring(0,5) : "09:00",
        max_members: course.max_members || 10,
        number_of_sessions: course.number_of_sessions || 4,
        session_price: course.session_price || "",
        salle: course.salle ? String(course.salle) : "",
      });
    } else {
      setFormData({
        name: "",
        coach: "",
        day: "MON",
        days: [],
        time: "09:00",
        max_members: 10,
        number_of_sessions: 4,
        session_price: "",
        salle: "",
      });
    }
  }, [course, isOpen]);

  // Fetch room availability when day/time changes
  useEffect(() => {
    const day = Array.isArray(formData.days) && formData.days.length > 0 ? formData.days[0] : formData.day;
    const time = formData.time && formData.time.length === 5 ? formData.time + ':00' : formData.time;
    if (!day || !time || salles.length === 0) return;
    let mounted = true;
    getRoomsAvailabilityApi(day, time, accessToken)
      .then((res) => {
        if (!mounted) return;
        const map: Record<number, { is_available: boolean; reason?: string }> = {};
        (res || []).forEach((r: any) => {
          map[r.id] = { is_available: !!r.is_available, reason: r.reason };
        });
        setRoomAvailability(map);
      })
      .catch(() => {});
    return () => { mounted = false; };
  }, [formData.time, formData.day, formData.days, salles]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value, type } = e.target as HTMLInputElement;
    setFormData((prev) => ({
      ...prev,
      [name]: (name === "max_members" || name === "number_of_sessions") ? (parseInt(value as string) || 0) : value,
    }));
  };

  const toggleDay = (dayCode: string) => {
    setFormData((prev) => {
      const days: string[] = Array.isArray(prev.days) ? [...prev.days] : [];
      const idx = days.indexOf(dayCode);
      if (idx === -1) days.push(dayCode);
      else days.splice(idx, 1);
      return { ...prev, days };
    });
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.name) {
      setError("Please provide a course name.");
      return;
    }
    if (!formData.coach) {
      setError("Please select a coach.");
      return;
    }
    if (!formData.salle) {
      setError("Please select a room (salle) for this course.");
      return;
    }
    if (formData.session_price === "" || formData.session_price === null) {
      setError("Please provide a price per session.");
      return;
    }
    setError("");
    setLoading(true);
    try {
      const payload: any = { ...formData };
      // coach is a string (coach id)
      payload.coach = String(formData.coach);
      // salle id (number)
      payload.salle = parseInt(String(formData.salle));
      // normalize price to number
      payload.session_price = parseFloat(String(formData.session_price));
      // normalize time to HH:MM:SS for backend
      if (payload.time && typeof payload.time === 'string' && payload.time.length === 5) {
        payload.time = payload.time + ':00';
      }
      // If editing an existing course, send single `day` (first selected or existing).
      if (course) {
        payload.day = Array.isArray(formData.days) && formData.days.length > 0 ? formData.days[0] : formData.day;
        delete payload.days;
      } else {
        // creating: send `days` array if provided, else send single `day` (from formData.day)
        if (Array.isArray(formData.days) && formData.days.length > 0) {
          payload.days = formData.days;
        } else {
          payload.day = formData.day;
        }
      }
      await onSave(payload);
      onClose();
    } catch (err: any) {
      console.error("Create course error:", err);
      // Provide helpful error text for validation objects returned by DRF
      const data = err?.data;
      if (!data) {
        setError(err?.message || "An error occurred");
      } else if (typeof data === 'string') {
        setError(data);
      } else if (data.error) {
        setError(String(data.error));
      } else if (typeof data === 'object') {
        try {
          const parts: string[] = [];
          Object.entries(data).forEach(([k, v]) => {
            const val = Array.isArray(v) ? v.join('; ') : String(v);
            parts.push(`${k}: ${val}`);
          });
          setError(parts.join(' | '));
        } catch {
          setError(JSON.stringify(data));
        }
      } else {
        setError("An unknown error occurred");
      }
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity" onClick={onClose} />
      <div className="relative w-full max-w-xl bg-[#0B1120] border border-white/10 rounded-2xl shadow-2xl p-6 overflow-hidden animate-fade-in-up md:p-8">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-24 bg-brand-green/20 blur-[100px] pointer-events-none" />
        <div className="flex justify-between items-center mb-6 relative">
          <div>
            <h2 className="text-2xl font-black text-white">{course ? "Edit Course" : "Create New Course"}</h2>
            <p className="text-sm text-text-muted mt-1">{course ? "Update course details." : "Create a new course offering."}</p>
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
            <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Name</label>
            <input name="name" value={formData.name} onChange={handleChange} required
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors" />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Coach</label>
              <select name="coach" value={formData.coach} onChange={handleChange} required
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors appearance-none">
                <option value="" disabled>Select coach</option>
                {loadingCoaches ? (
                  <option disabled>Loading...</option>
                ) : (
                  coaches.map(c => (
                    <option key={c.id} value={c.id}>{c.first_name} {c.last_name} - {c.email}</option>
                  ))
                )}
              </select>
            </div>

            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Days (pick one or more)</label>
              <div className="grid grid-cols-4 gap-2">
                {WEEK_DAYS.map(({ code, label }) => {
                  const active = Array.isArray(formData.days) && formData.days.includes(code);
                  return (
                    <button
                      key={code}
                      type="button"
                      onClick={() => toggleDay(code)}
                      className={`px-3 py-2 rounded-lg text-sm font-semibold transition-colors ${active ? 'bg-brand-green text-[#0B1120]' : 'bg-white/5 text-text-muted hover:bg-white/10'}`}>
                      {label.slice(0,3)}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Time</label>
              <input type="time" name="time" value={formData.time} onChange={handleChange} required
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors" />
            </div>

            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Max Members</label>
              <input type="number" name="max_members" value={formData.max_members} onChange={handleChange} min={1} required
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors" />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Number of Sessions</label>
              <input type="number" name="number_of_sessions" value={formData.number_of_sessions} onChange={handleChange} min={1} required
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors" />
            </div>
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Price per Session</label>
              <input name="session_price" value={formData.session_price || ""} onChange={handleChange} required
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors" />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Room (Salle)</label>
            <select name="salle" value={formData.salle} onChange={handleChange} required
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors appearance-none">
              <option value="" disabled>Select room</option>
              {loadingSalles ? (
                <option disabled>Loading...</option>
              ) : (
                salles.map(s => {
                  const avail = roomAvailability[s.id];
                  const disabled = avail ? !avail.is_available : false;
                  const label = `${s.name}${s.capacity ? ` — ${s.capacity}` : ''}${avail && !avail.is_available ? ` (Booked: ${avail.reason})` : ''}`;
                  return (
                    <option key={s.id} value={s.id} disabled={disabled}>{label}</option>
                  );
                })
              )}
            </select>
          </div>

          <div className="pt-4 flex justify-end gap-3 border-t border-white/5 mt-6">
            <button type="button" onClick={onClose}
              className="px-6 py-2.5 rounded-xl text-sm font-bold text-white hover:bg-white/5 transition-all">
              CANCEL
            </button>
            <button type="submit" disabled={loading}
              className="px-6 py-2.5 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-black tracking-wider transition-all hover:shadow-[0_0_20px_rgba(46,204,112,0.4)] disabled:opacity-50">
              {loading ? "SAVING..." : (course ? "SAVE CHANGES" : "CREATE COURSE")}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
