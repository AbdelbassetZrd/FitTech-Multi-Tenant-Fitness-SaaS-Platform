import React from 'react';

interface ConfirmModalProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  isDestructive?: boolean;
}

export default function ConfirmModal({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  confirmText = "CONFIRM",
  cancelText = "CANCEL",
  isDestructive = true
}: ConfirmModalProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity" 
        onClick={onClose} 
      />
      
      {/* Modal */}
      <div className="relative w-full max-w-md bg-[#0B1120] border border-white/10 rounded-2xl shadow-2xl p-6 overflow-hidden animate-fade-in-up">
        {/* Glow effect */}
        <div className={`absolute top-0 left-1/2 -translate-x-1/2 w-3/4 h-24 blur-[100px] pointer-events-none ${isDestructive ? 'bg-red-500/20' : 'bg-brand-green/20'}`} />

        <div className="flex justify-between items-start mb-6 relative">
          <div>
            <h2 className="text-xl font-black text-white">{title}</h2>
            <p className="text-sm text-text-muted mt-2">{message}</p>
          </div>
          <button 
            onClick={onClose}
            className="p-2 text-white/50 hover:text-white hover:bg-white/10 rounded-xl transition-colors ml-4 shrink-0"
          >
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-5 h-5">
              <path strokeLinecap="round" strokeLinejoin="round" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <div className="pt-4 flex justify-end gap-3 border-t border-white/5 mt-6 relative">
          <button type="button" onClick={onClose}
            className="px-6 py-2.5 rounded-xl text-sm font-bold text-white hover:bg-white/5 transition-all">
            {cancelText}
          </button>
          <button type="button" onClick={onConfirm}
            className={`px-6 py-2.5 rounded-xl text-sm font-bold transition-all ${
              isDestructive 
              ? "bg-red-500 hover:bg-red-400 text-white hover:shadow-lg hover:shadow-red-500/20" 
              : "bg-brand-green hover:bg-brand-green-light text-[#0B1120] hover:shadow-lg hover:shadow-brand-green/20"
            }`}>
            {confirmText}
          </button>
        </div>
      </div>
    </div>
  );
}
