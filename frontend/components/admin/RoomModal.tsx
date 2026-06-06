"use client";

"use client";

import React, { useEffect, useState } from 'react';
import { createRoomApi, updateRoomApi } from '../../lib/api';
import { useAuthStore } from '@/lib/stores/authStore';

type Room = {
  id?: number;
  name: string;
  capacity?: number;
  location?: string;
  description?: string;
};

export default function RoomModal({ open, room, onClose, onSaved }: {
  open: boolean;
  room?: Room | null;
  onClose: () => void;
  onSaved: (r: Room) => void;
}) {
  const accessToken = useAuthStore(s => s.accessToken);
  const [form, setForm] = useState<Room>({ name: '', capacity: 20, location: '', description: '' });
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (room) setForm(room);
    else setForm({ name: '', capacity: 20, location: '', description: '' });
  }, [room, open]);

  if (!open) return null;

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    setError(null);
    try {
      const payload = { ...form };
      let res;
      if (room?.id) res = await updateRoomApi(room.id, payload, accessToken);
      else res = await createRoomApi(payload, accessToken);
      onSaved(res);
      onClose();
    } catch (err: any) {
      setError(err?.data || err?.message || 'Failed to save room');
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="bg-gray-900 rounded-lg w-full max-w-lg p-6 shadow-lg">
        <h3 className="text-lg font-semibold mb-3">{room ? 'Edit Room' : 'Add Room'}</h3>
        {error && <div className="bg-red-900 text-red-300 p-2 rounded mb-3">{error}</div>}
        <form onSubmit={handleSubmit} className="space-y-3">
          <div>
            <label className="block text-sm text-gray-300">Name</label>
            <input required value={form.name} onChange={e => setForm({...form, name: e.target.value})}
              className="w-full mt-1 p-2 rounded bg-gray-800 border border-gray-700" />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-sm text-gray-300">Capacity</label>
              <input type="number" min={1} value={form.capacity} onChange={e => setForm({...form, capacity: Number(e.target.value)})}
                className="w-full mt-1 p-2 rounded bg-gray-800 border border-gray-700" />
            </div>
            <div>
              <label className="block text-sm text-gray-300">Location</label>
              <input value={form.location} onChange={e => setForm({...form, location: e.target.value})}
                className="w-full mt-1 p-2 rounded bg-gray-800 border border-gray-700" />
            </div>
          </div>
          <div>
            <label className="block text-sm text-gray-300">Description</label>
            <textarea value={form.description} onChange={e => setForm({...form, description: e.target.value})}
              className="w-full mt-1 p-2 rounded bg-gray-800 border border-gray-700" />
          </div>

          <div className="flex justify-end gap-2 mt-4">
            <button type="button" onClick={onClose} className="px-4 py-2 rounded bg-transparent border border-gray-700 text-gray-300">Cancel</button>
            <button type="submit" disabled={saving} className="px-4 py-2 rounded bg-green-500 text-black font-semibold">{saving ? 'Saving...' : (room ? 'Update' : 'Create')}</button>
          </div>
        </form>
      </div>
    </div>
  );
}
