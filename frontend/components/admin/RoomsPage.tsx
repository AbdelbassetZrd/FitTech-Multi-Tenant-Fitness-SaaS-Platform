"use client";

import React, { useEffect, useState } from 'react';
import { getRoomsApi, deleteRoomApi, getRoomsAvailabilityApi, getAdminCoursesApi } from '../../lib/api';
import { useAuthStore } from '@/lib/stores/authStore';
import RoomModal from './RoomModal';

const WEEKDAYS = [
  { code: 'MON', label: 'Mon' }, { code: 'TUE', label: 'Tue' }, { code: 'WED', label: 'Wed' },
  { code: 'THU', label: 'Thu' }, { code: 'FRI', label: 'Fri' }, { code: 'SAT', label: 'Sat' }, { code: 'SUN', label: 'Sun' }
];

function timeToHHMMSS(t: string) {
  const m = t.match(/(\d{1,2}):(\d{2})/);
  if (!m) return '00:00:00';
  return `${m[1].padStart(2,'0')}:${m[2]}:00`;
}

export default function RoomsPage() {
  const accessToken = useAuthStore(s => s.accessToken);
  const [rooms, setRooms] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [day, setDay] = useState(WEEKDAYS[0].code);
  const [time, setTime] = useState('09:00');
  const [unavailableIds, setUnavailableIds] = useState<number[]>([]);
  const [openModal, setOpenModal] = useState(false);
  const [editing, setEditing] = useState<any | null>(null);
  const [expanded, setExpanded] = useState<Record<number, boolean>>({});
  const [courses, setCourses] = useState<any[]>([]);

  async function load() {
    setLoading(true);
    try {
      const r = await getRoomsApi(accessToken);
      setRooms(r || []);
      const c = await getAdminCoursesApi(accessToken as any).catch(() => []);
      setCourses(c || []);
      const avail = await getRoomsAvailabilityApi(day, timeToHHMMSS(time), accessToken);
      if (Array.isArray(avail)) {
        // API returns array of room availability objects - collect unavailable ids
        const ids = (avail as any[]).filter(r => r && r.is_available === false).map(r => r.id);
        setUnavailableIds(ids);
      } else setUnavailableIds((avail as any)?.unavailable || []);
    } catch (err) {
      console.error(err);
    } finally { setLoading(false); }
  }

  useEffect(() => { load(); }, [day, time]);

  async function handleDelete(id: number) {
    if (!confirm('Delete room?')) return;
    await deleteRoomApi(id, accessToken);
    setRooms(prev => prev.filter(r => r.id !== id));
  }

  function occupantsForRoom(roomId: number) {
    return courses.filter(c => c.salle === roomId);
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className="text-xl font-semibold">Rooms</h2>
          <div className="text-sm text-gray-400 mt-1">Room statistics for selected day/time</div>
        </div>
        <div className="flex gap-2">
          <select value={day} onChange={e => setDay(e.target.value)} className="p-2 bg-gray-800 rounded">
            {WEEKDAYS.map(d => <option key={d.code} value={d.code}>{d.label}</option>)}
          </select>
          <input type="time" value={time} onChange={e => setTime(e.target.value)} className="p-2 bg-gray-800 rounded" />
          <button onClick={() => { setEditing(null); setOpenModal(true); }} className="px-3 py-2 bg-green-500 rounded">Add Room</button>
        </div>
      </div>
      {/* Statistics */}
      <div className="grid grid-cols-3 gap-4 my-4">
        <div className="bg-gray-900 p-4 rounded">
          <div className="text-sm text-gray-400">Total Rooms</div>
          <div className="text-xl font-bold">{rooms.length}</div>
        </div>
        <div className="bg-gray-900 p-4 rounded">
          <div className="text-sm text-gray-400">Occupied</div>
          <div className="text-xl font-bold text-red-400">{unavailableIds.length}</div>
        </div>
        <div className="bg-gray-900 p-4 rounded">
          <div className="text-sm text-gray-400">Total Capacity</div>
          <div className="text-xl font-bold">{rooms.reduce((s, r) => s + (r.capacity || 0), 0)}</div>
        </div>
      </div>

      {loading ? <div>Loading…</div> : (
        <div className="space-y-3">
          {rooms.map(room => {
            const occupied = unavailableIds.includes(room.id);
            const occList = occupantsForRoom(room.id);
            return (
              <div key={room.id} className="bg-gray-900 rounded p-4 flex flex-col">
                <div className="flex items-center justify-between">
                  <div>
                    <div className="font-semibold">{room.name} <span className="text-sm text-gray-400">({room.location || '—'})</span></div>
                    <div className="text-sm text-gray-400">Capacity: {room.capacity || '—'}</div>
                  </div>
                  <div className="flex items-center gap-2">
                    <span className={`px-2 py-1 rounded text-sm ${occupied ? 'bg-red-600 text-white' : 'bg-green-600 text-black'}`}>{occupied ? 'Occupied' : 'Available'}</span>
                    <button onClick={() => { setEditing(room); setOpenModal(true); }} className="px-2 py-1 bg-gray-800 rounded">Edit</button>
                    <button onClick={() => handleDelete(room.id)} className="px-2 py-1 bg-red-700 rounded">Delete</button>
                    <button onClick={() => setExpanded(s => ({...s, [room.id]: !s[room.id]}))} className="px-2 py-1 bg-gray-800 rounded">{expanded[room.id] ? 'Hide' : 'Show'}</button>
                  </div>
                </div>

                {expanded[room.id] && (
                  <div className="mt-3 border-t border-gray-800 pt-3">
                    <div className="text-sm text-gray-300 mb-2">Occupying courses:</div>
                    {occList.length === 0 ? (
                      <div className="text-sm text-gray-400">None for selected day/time.</div>
                    ) : (
                      <ul className="space-y-2">
                        {occList.map(c => (
                          <li key={c.id} className="p-2 bg-gray-800 rounded">
                            <div className="flex justify-between">
                              <div>
                                <div className="font-medium">{c.name}</div>
                                <div className="text-sm text-gray-400">{c.day} • {c.time}</div>
                                <div className="text-sm text-gray-400">Coach: {c.coach_name || c.coach}</div>
                              </div>
                              <div className="text-sm text-gray-400">Sessions: {c.number_of_sessions}</div>
                            </div>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}

      <RoomModal open={openModal} room={editing} onClose={() => setOpenModal(false)} onSaved={(r: any) => { load(); }} />
    </div>
  );
}
