import React, { useState, useEffect, useRef, useCallback } from "react";
import { CoachProfile, assignNFCDeviceApi } from "@/lib/api";

interface CoachModalProps {
  isOpen: boolean;
  onClose: () => void;
  coach?: CoachProfile | null;
  onSave: (payload: any) => Promise<CoachProfile>;
  accessToken?: string;
}

export default function CoachModal({ isOpen, onClose, coach, onSave, accessToken }: CoachModalProps) {
  const [formData, setFormData] = useState({
    first_name: "",
    last_name: "",
    email: "",
    password: "",
    phone: "",
    specialities: "",
    bio: "",
    years_of_experience: 0,
    nfc_uid: "",
    nfc_device_type: "card",
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [isSpecialitiesOpen, setIsSpecialitiesOpen] = useState(false);

  const [nfcScanning, setNfcScanning] = useState(false);
  const nfcPollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const stopNfcCapture = useCallback(() => {
    setNfcScanning(false);
    if (nfcPollRef.current) { clearInterval(nfcPollRef.current); nfcPollRef.current = null; }
  }, []);

  const startNfcCapture = useCallback(() => {
    setNfcScanning(true);
    nfcPollRef.current = setInterval(async () => {
      try {
        const backendUrl = process.env.NEXT_PUBLIC_API_BASE_URL || "https://providing-april-manger.ngrok-free.dev";
        const res = await fetch(`${backendUrl}/api/access/capture-uid/?session_id=default`,
          { headers: { "ngrok-skip-browser-warning": "true", "Accept": "application/json" } });
        const data = await res.json();
        if (data.uid) {
          setFormData((f) => ({ ...f, nfc_uid: data.uid }));
          stopNfcCapture();
        }
      } catch (_) {}
    }, 1000);
  }, [stopNfcCapture]);

  useEffect(() => () => stopNfcCapture(), [stopNfcCapture]);

  useEffect(() => {
    if (coach) {
      setFormData({
        first_name: coach.first_name || "",
        last_name: coach.last_name || "",
        email: coach.email || "",
        password: "",
        phone: coach.phone || "",
        specialities: coach.specialities || "",
        bio: coach.bio || "",
        years_of_experience: coach.years_of_experience || 0,
        nfc_uid: "",
        nfc_device_type: "card",
      });
    } else {
      setFormData({
        first_name: "",
        last_name: "",
        email: "",
        password: "",
        phone: "",
        specialities: "",
        bio: "",
        years_of_experience: 0,
        nfc_uid: "",
        nfc_device_type: "card",
      });
    }
    stopNfcCapture();
  }, [coach, isOpen]);

  if (!isOpen) return null;

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setFormData((prev) => ({
      ...prev,
      [name]: name === "years_of_experience" ? parseInt(value) || 0 : value,
    }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const payload: any = { ...formData };
      if (coach && !payload.password) delete payload.password;
      delete payload.nfc_uid;
      delete payload.nfc_device_type;

      const saved = await onSave(payload);

      // Auto-assign NFC only on creation and if UID provided
      if (!coach && formData.nfc_uid.trim() && accessToken) {
        try {
          await assignNFCDeviceApi(
            { user_id: String(saved.id), uid: formData.nfc_uid.trim(), device_type: formData.nfc_device_type, role: "coach" },
            accessToken,
          );
        } catch (nfcErr: any) {
          setError(`Coach created, but NFC assignment failed: ${nfcErr?.data?.error || nfcErr?.message || "Unknown error"}`);
          setLoading(false);
          return;
        }
      }
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
      <div 
        className="absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity" 
        onClick={onClose} 
      />
      
      {/* Modal */}
      <div className="relative w-full max-w-2xl bg-[#0B1120] border border-white/10 rounded-2xl shadow-2xl p-6 overflow-hidden animate-fade-in-up">
        {/* Glow effect */}
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-24 bg-brand-green/20 blur-[100px] pointer-events-none" />

        <div className="flex justify-between items-center mb-6 relative">
          <div>
            <h2 className="text-2xl font-black text-white">{coach ? "Edit Coach" : "Add New Coach"}</h2>
            <p className="text-sm text-text-muted mt-1">{coach ? "Update the coach's profile details." : "Enter the details for the new coach."}</p>
          </div>
          <button 
            onClick={onClose}
            className="p-2 text-white/50 hover:text-white hover:bg-white/10 rounded-xl transition-colors"
          >
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

        <form onSubmit={handleSubmit} className="space-y-4 relative max-h-[70vh] overflow-y-auto pr-2 custom-scrollbar">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">First Name</label>
              <input required type="text" name="first_name" value={formData.first_name} onChange={handleChange}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
                placeholder="Jane" />
            </div>
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Last Name</label>
              <input required type="text" name="last_name" value={formData.last_name} onChange={handleChange}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
                placeholder="Doe" />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Email</label>
              <input required type="email" name="email" value={formData.email} onChange={handleChange}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
                placeholder="jane.doe@example.com" />
            </div>
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Phone</label>
              <input type="text" name="phone" value={formData.phone} onChange={handleChange}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
                placeholder="+1234567890" />
            </div>
          </div>

          {!coach && (
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Temporary Password</label>
              <input required={!coach} type="password" name="password" value={formData.password} onChange={handleChange}
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
                placeholder="••••••••" />
            </div>
          )}

          <div className="grid grid-cols-[2fr_1fr] gap-4">
            <div className="space-y-1.5 z-40">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Specialities</label>
              <div className="relative">
                <button
                  type="button"
                  onClick={() => setIsSpecialitiesOpen(!isSpecialitiesOpen)}
                  className="w-full bg-[#0B1120] border border-white/10 rounded-xl px-4 py-2.5 text-left focus:outline-none focus:border-brand-green/50 focus:bg-[#0B1120] transition-colors flex justify-between items-center"
                >
                  <span className={formData.specialities ? "text-white" : "text-white/50"}>
                    {formData.specialities 
                      ? [
                          { value: 'crossfit', label: 'CrossFit' },
                          { value: 'yoga', label: 'Yoga' },
                          { value: 'spinning', label: 'Spinning' },
                          { value: 'pilates', label: 'Pilates' },
                          { value: 'cardio', label: 'Cardio' },
                          { value: 'strength', label: 'Strength Training' },
                          { value: 'nutrition', label: 'Nutrition' },
                          { value: 'other', label: 'Other' },
                        ].find(opt => opt.value === formData.specialities)?.label || formData.specialities
                      : "Select Speciality..."}
                  </span>
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className={`w-4 h-4 text-white/50 transition-transform ${isSpecialitiesOpen ? "rotate-180" : ""}`}>
                    <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
                  </svg>
                </button>

                {isSpecialitiesOpen && (
                  <>
                    <div className="fixed inset-0 z-40" onClick={() => setIsSpecialitiesOpen(false)} />
                    <div className="absolute z-50 w-full mt-2 bg-[#0B1120] border border-white/10 rounded-xl shadow-[0_8px_30px_rgb(0,0,0,0.5)] overflow-hidden py-1 max-h-52 overflow-y-auto custom-scrollbar">
                      {[
                        { value: 'crossfit', label: 'CrossFit' },
                        { value: 'yoga', label: 'Yoga' },
                        { value: 'spinning', label: 'Spinning' },
                        { value: 'pilates', label: 'Pilates' },
                        { value: 'cardio', label: 'Cardio' },
                        { value: 'strength', label: 'Strength Training' },
                        { value: 'nutrition', label: 'Nutrition' },
                        { value: 'other', label: 'Other' },
                      ].map((opt) => (
                        <button
                          key={opt.value}
                          type="button"
                          onClick={() => {
                            handleChange({ target: { name: 'specialities', value: opt.value } } as any);
                            setIsSpecialitiesOpen(false);
                          }}
                          className={`w-full text-left px-4 py-2.5 text-sm transition-all duration-200 hover:bg-brand-green/10 hover:text-brand-green ${
                            formData.specialities === opt.value ? "bg-brand-green/20 text-brand-green font-bold" : "text-white/80"
                          }`}
                        >
                          {opt.label}
                        </button>
                      ))}
                    </div>
                  </>
                )}
              </div>
            </div>
            <div className="space-y-1.5">
              <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Experience (Yrs)</label>
              <input required type="number" name="years_of_experience" value={formData.years_of_experience} onChange={handleChange} min="0" max="50"
                className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors"
                placeholder="3" />
            </div>
          </div>

          <div className="space-y-1.5">
            <label className="text-[11px] font-bold tracking-widest text-white/50 uppercase">Bio</label>
            <textarea name="bio" value={formData.bio} onChange={handleChange} rows={3}
              className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-white placeholder-white/20 focus:outline-none focus:border-brand-green/50 focus:bg-white/10 transition-colors resize-none"
              placeholder="Short description of coach's background..." />
          </div>

          {/* NFC Access Card — only shown when creating */}
          {!coach && (
            <div className="space-y-2 p-4 bg-white/[0.02] border border-white/[0.06] rounded-xl">
              <p className="text-[10px] font-bold text-white/40 uppercase tracking-[0.2em]">NFC Access Card <span className="font-normal normal-case tracking-normal text-white/25">(optional)</span></p>
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
              <div className="relative">
                <input type="text" value={formData.nfc_uid}
                  onChange={(e) => setFormData({ ...formData, nfc_uid: e.target.value.toUpperCase() })}
                  placeholder={nfcScanning ? "Tap card on reader…" : "Auto-filled on scan · or type manually"}
                  className={`w-full bg-white/5 border rounded-xl px-4 py-2.5 text-sm text-white placeholder-white/20 focus:outline-none transition-all font-mono tracking-wider ${
                    nfcScanning ? "border-yellow-500/40" : formData.nfc_uid ? "border-brand-green/40" : "border-white/10"
                  }`} />
                {formData.nfc_uid && (
                  <button type="button" onClick={() => setFormData({ ...formData, nfc_uid: "" })}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-white/30 hover:text-white transition-colors">
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-3.5 h-3.5"><path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" /></svg>
                  </button>
                )}
              </div>
              <div className="flex gap-2">
                {(["card", "phone"] as const).map((t) => (
                  <button key={t} type="button" onClick={() => setFormData({ ...formData, nfc_device_type: t })}
                    className={`flex-1 py-1.5 rounded-lg text-xs font-bold transition-all border ${
                      formData.nfc_device_type === t ? "bg-brand-green/15 border-brand-green/40 text-brand-green" : "bg-white/[0.03] border-white/10 text-white/40 hover:border-white/20"
                    }`}>
                    {t === "card" ? "🪪  Physical Card" : "📱  Phone NFC"}
                  </button>
                ))}
              </div>
            </div>
          )}

          <div className="pt-4 flex justify-end gap-3 border-t border-white/5 mt-6">
            <button type="button" onClick={onClose}
              className="px-6 py-2.5 rounded-xl text-sm font-bold text-white hover:bg-white/5 transition-all">
              CANCEL
            </button>
            <button type="submit" disabled={loading}
              className="px-6 py-2.5 bg-brand-green hover:bg-brand-green-light text-[#0B1120] rounded-xl text-sm font-bold transition-all hover:shadow-lg hover:shadow-brand-green/20 disabled:opacity-50 disabled:cursor-not-allowed">
              {loading ? "SAVING..." : "SAVE COACH"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
