"use client";

import React, { useState, useEffect, useRef } from "react";
import AdminHeader from "@/components/admin/AdminHeader";
import { useAuthStore } from "@/lib/stores/authStore";
import { getContactsApi, type ChatContact } from "@/lib/api";
import { useChat, type ChatMessage } from "@/lib/hooks/useChat";

export default function MessagesPage() {
  const accessToken = useAuthStore((s) => s.accessToken);
  const user = useAuthStore((s) => s.user);

  /* ── Contacts state ─────────────────────────────────────────────────── */
  const [contacts, setContacts] = useState<ChatContact[]>([]);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [contactsLoading, setContactsLoading] = useState(true);
  const [contactsError, setContactsError] = useState<string | null>(null);

  const [searchQuery, setSearchQuery] = useState("");
  const [roleFilter, setRoleFilter] = useState<string>("all");
  const [activeContact, setActiveContact] = useState<ChatContact | null>(null);
  const [contactActivity, setContactActivity] = useState<Record<string, number>>({});

  /* ── Chat hook ──────────────────────────────────────────────────────── */
  const { messages, sendMessage, isConnected, isConnecting } = useChat({
    contactId: activeContact?.id ?? null,
    accessToken,
  });

  /* ── Input state ────────────────────────────────────────────────────── */
  const [inputText, setInputText] = useState("");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  /* ── Load contacts on mount ─────────────────────────────────────────── */
  useEffect(() => {
    if (!accessToken) return;
    let cancelled = false;

    (async () => {
      setContactsLoading(true);
      setContactsError(null);
      try {
        const res = await getContactsApi(accessToken);
        if (cancelled) return;
        setContacts(res.contacts);
        setCurrentUserId(res.current_user_id);
        // Auto-select contact based on URL parameter or fallback to first
        if (res.contacts.length > 0) {
          const urlParams = new URLSearchParams(window.location.search);
          const contactIdParam = urlParams.get("contactId");
          
          if (contactIdParam) {
            const targetContact = res.contacts.find((c: ChatContact) => String(c.id) === contactIdParam);
            setActiveContact(targetContact || res.contacts[0]);
          } else {
            setActiveContact(res.contacts[0]);
          }
        }
      } catch (err: any) {
        if (!cancelled) {
          setContactsError(err.message || "Failed to load contacts");
        }
      } finally {
        if (!cancelled) setContactsLoading(false);
      }
    })();

    return () => { cancelled = true; };
  }, [accessToken]);

  /* ── Auto-scroll on new messages ────────────────────────────────────── */
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
    
    // Update contact activity when new messages arrive
    if (messages.length > 0 && activeContact) {
      const lastMsg = messages[messages.length - 1];
      const time = new Date(lastMsg.created_at).getTime();
      setContactActivity(prev => ({
        ...prev,
        [activeContact.id]: Math.max(prev[activeContact.id] || 0, time)
      }));
    }
  }, [messages, activeContact]);

  /* ── Helpers ─────────────────────────────────────────────────────────── */
  const handleSendMessage = (e: React.FormEvent) => {
    e.preventDefault();
    if (!inputText.trim()) return;
    sendMessage(inputText.trim());
    setInputText("");
  };

  const isMine = (msg: ChatMessage) => {
    if (!currentUserId) return false;
    return msg.sender_id === currentUserId;
  };

  const formatTime = (iso: string) => {
    try {
      const d = new Date(iso);
      if (isNaN(d.getTime())) return iso;
      return d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    } catch {
      return iso;
    }
  };

  const getInitial = (name: string) => {
    return name?.charAt(0)?.toUpperCase() || "?";
  };

  const getRoleBadgeColor = (role: string) => {
    switch (role) {
      case "admin": return "bg-purple-500/20 text-purple-400 border-purple-500/30";
      case "coach": return "bg-blue-500/20 text-blue-400 border-blue-500/30";
      case "member": return "bg-emerald-500/20 text-emerald-400 border-emerald-500/30";
      case "bot": return "bg-amber-500/20 text-amber-400 border-amber-500/30";
      default: return "bg-white/10 text-text-muted border-white/10";
    }
  };

  const filteredContacts = contacts.filter(
    (c) =>
      (c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
       c.role.toLowerCase().includes(searchQuery.toLowerCase())) &&
      (roleFilter === "all" || c.role === roleFilter)
  ).sort((a, b) => {
    const timeA = contactActivity[a.id] || 0;
    const timeB = contactActivity[b.id] || 0;
    return timeB - timeA;
  });

  return (
    <div className="flex flex-col h-screen overflow-hidden">
      <AdminHeader />

      <div className="flex flex-1 overflow-hidden p-6 gap-6">

        {/* ── Left Pane: Contact List ─────────────────────────────────── */}
        <div className="w-full md:w-80 lg:w-96 flex flex-col bg-[#111827]/80 border border-white/5 rounded-2xl overflow-hidden animate-fade-in-up">
          <div className="p-4 border-b border-white/5">
            <h2 className="text-lg font-bold text-white mb-4 flex items-center justify-between">
              Messages
              {contacts.length > 0 && (
                <span className="bg-brand-green/20 text-brand-green text-[10px] px-2 py-0.5 rounded-full">
                  {contacts.length} CONTACTS
                </span>
              )}
            </h2>
            <div className="relative mb-4">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={2} stroke="currentColor" className="w-4 h-4 absolute left-3.5 top-1/2 -translate-y-1/2 text-text-muted/50">
                <path strokeLinecap="round" strokeLinejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
              </svg>
              <input
                type="text"
                placeholder="Search conversations..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full bg-white/5 border border-white/5 rounded-xl pl-10 pr-4 py-2.5 text-sm text-white placeholder-text-muted/40 focus:outline-none focus:border-brand-green/30 focus:bg-white/10 transition-all duration-300"
              />
            </div>

            {/* Role Filter */}
            <div className="flex items-center gap-2 overflow-x-auto pb-1 scrollbar-hide">
              {["all", "admin", "coach", "member", "bot"].map((role) => (
                <button
                  key={role}
                  onClick={() => setRoleFilter(role)}
                  className={`px-3 py-1.5 rounded-lg text-xs font-bold capitalize whitespace-nowrap transition-all ${
                    roleFilter === role
                      ? "bg-brand-green text-[#0B1120]"
                      : "bg-white/5 text-text-muted hover:bg-white/10 hover:text-white"
                  }`}
                >
                  {role === "all" ? "All" : role + "s"}
                </button>
              ))}
            </div>
          </div>

          <div className="flex-1 overflow-y-auto overflow-x-hidden">
            {contactsLoading ? (
              <div className="flex flex-col items-center justify-center py-16 gap-3">
                <div className="w-8 h-8 rounded-full border-2 border-brand-green/20 border-t-brand-green animate-spin" />
                <p className="text-xs text-text-muted animate-pulse">Loading contacts…</p>
              </div>
            ) : contactsError ? (
              <div className="flex flex-col items-center justify-center py-16 gap-3 px-4 text-center">
                <div className="w-10 h-10 rounded-full bg-red-500/10 flex items-center justify-center">
                  <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5 text-red-400">
                    <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
                  </svg>
                </div>
                <p className="text-xs text-red-400">{contactsError}</p>
              </div>
            ) : filteredContacts.length === 0 ? (
              <div className="flex flex-col items-center justify-center py-16 gap-2">
                <p className="text-xs text-text-muted">No contacts found</p>
              </div>
            ) : (
              filteredContacts.map((contact) => (
                <div
                  key={contact.id}
                  onClick={() => setActiveContact(contact)}
                  className={`flex items-start gap-3 p-4 cursor-pointer transition-all border-l-2 ${
                    activeContact?.id === contact.id
                      ? "bg-white/10 border-brand-green"
                      : "border-transparent hover:bg-white/5"
                  }`}
                >
                  <div className="relative flex-shrink-0 mt-0.5">
                    <div
                      className={`w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm border ${
                        activeContact?.id === contact.id
                          ? "bg-brand-green/20 border-brand-green/50 text-brand-green"
                          : "bg-white/5 border-white/10 text-white"
                      }`}
                    >
                      {contact.role === "bot" ? "🤖" : getInitial(contact.name)}
                    </div>
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-1">
                      <p className="text-sm font-bold text-white truncate">{contact.name}</p>
                    </div>
                    <span className={`inline-flex items-center text-[10px] px-1.5 py-0.5 rounded-md border font-medium ${getRoleBadgeColor(contact.role)}`}>
                      {contact.role}
                    </span>
                    {contact.description && (
                      <p className="text-[11px] text-text-muted mt-1 truncate">{contact.description}</p>
                    )}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* ── Right Pane: Chat Window ─────────────────────────────────── */}
        <div className="hidden md:flex flex-1 flex-col bg-[#111827]/80 border border-white/5 rounded-2xl overflow-hidden animate-fade-in-up" style={{ animationDelay: "0.1s" }}>
          {activeContact ? (
            <>
              {/* Chat Header */}
              <div className="flex items-center justify-between p-4 border-b border-white/5 bg-white/5">
                <div className="flex items-center gap-3">
                  <div className="relative">
                    <div className="w-10 h-10 rounded-full bg-brand-green/20 border border-brand-green/50 flex items-center justify-center text-brand-green font-bold text-sm">
                      {activeContact.role === "bot" ? "🤖" : getInitial(activeContact.name)}
                    </div>
                    {isConnected && (
                      <div className="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-brand-green rounded-full border-2 border-[#111827]" />
                    )}
                  </div>
                  <div>
                    <h3 className="text-sm font-bold text-white leading-tight">{activeContact.name}</h3>
                    <p className={`text-[11px] font-medium ${
                      isConnected
                        ? "text-brand-green"
                        : isConnecting
                        ? "text-amber-400"
                        : "text-text-muted"
                    }`}>
                      {isConnected ? "Connected" : isConnecting ? "Connecting…" : "Disconnected"}
                    </p>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  {/* Connection status dot */}
                  <div className={`w-2 h-2 rounded-full ${
                    isConnected ? "bg-brand-green animate-pulse" : isConnecting ? "bg-amber-400 animate-pulse" : "bg-red-400"
                  }`} />
                  <span className="text-[10px] text-text-muted mr-2">
                    {isConnected ? "Live" : isConnecting ? "Connecting" : "Offline"}
                  </span>
                  <button className="p-2 text-text-muted hover:text-white hover:bg-white/10 rounded-lg transition-colors ml-2">
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-5 h-5">
                      <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.75a.75.75 0 110-1.5.75.75 0 010 1.5zM12 12.75a.75.75 0 110-1.5.75.75 0 010 1.5zM12 18.75a.75.75 0 110-1.5.75.75 0 010 1.5z" />
                    </svg>
                  </button>
                </div>
              </div>

              {/* Messages Area */}
              <div className="flex-1 overflow-y-auto p-4 space-y-4 bg-[#0a0f18]/50">
                {isConnecting && messages.length === 0 && (
                  <div className="flex flex-col items-center justify-center h-full gap-3">
                    <div className="w-8 h-8 rounded-full border-2 border-brand-green/20 border-t-brand-green animate-spin" />
                    <p className="text-xs text-text-muted animate-pulse">Connecting to chat…</p>
                  </div>
                )}

                {!isConnecting && !isConnected && messages.length === 0 && (
                  <div className="flex flex-col items-center justify-center h-full gap-3">
                    <div className="w-12 h-12 rounded-full bg-red-500/10 flex items-center justify-center">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-6 h-6 text-red-400">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z" />
                      </svg>
                    </div>
                    <p className="text-sm text-text-muted">Unable to connect</p>
                    <p className="text-xs text-text-muted/60">Check that the server is running</p>
                  </div>
                )}

                {isConnected && messages.length === 0 && (
                  <div className="flex flex-col items-center justify-center h-full gap-3">
                    <div className="w-12 h-12 rounded-full bg-brand-green/10 flex items-center justify-center">
                      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor" className="w-6 h-6 text-brand-green">
                        <path strokeLinecap="round" strokeLinejoin="round" d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z" />
                      </svg>
                    </div>
                    <p className="text-sm text-text-muted">No messages yet</p>
                    <p className="text-xs text-text-muted/60">Say hello to start the conversation</p>
                  </div>
                )}

                {messages.map((msg, idx) => {
                  const mine = isMine(msg);
                  return (
                    <div key={`${msg.created_at}-${idx}`} className={`flex flex-col max-w-[80%] ${mine ? "ml-auto items-end" : "mr-auto items-start"}`}>
                      {!mine && (
                        <span className="text-[10px] text-text-muted mb-1 px-1 font-medium">{msg.sender_name}</span>
                      )}
                      <div
                        className={`px-4 py-2.5 rounded-2xl text-sm whitespace-pre-wrap break-words ${
                          mine
                            ? "bg-brand-green text-[#0B1120] rounded-tr-sm font-medium"
                            : "bg-[#1e293b] text-white rounded-tl-sm border border-white/5"
                        }`}
                      >
                        {msg.message}
                      </div>
                      <span className="text-[10px] text-text-muted mt-1.5 px-1">{formatTime(msg.created_at)}</span>
                    </div>
                  );
                })}
                <div ref={messagesEndRef} />
              </div>

              {/* Input Area */}
              <div className="p-4 border-t border-white/5 bg-[#111827]">
                <form onSubmit={handleSendMessage} className="flex gap-3">
                  <input
                    type="text"
                    placeholder={`Message ${activeContact.name}...`}
                    value={inputText}
                    onChange={(e) => setInputText(e.target.value)}
                    disabled={!isConnected}
                    className="flex-1 bg-white/5 border border-white/10 rounded-xl px-4 py-3 text-sm text-white placeholder-text-muted focus:outline-none focus:border-brand-green/30 focus:bg-white/10 transition-all disabled:opacity-40 disabled:cursor-not-allowed"
                  />

                  <button
                    type="submit"
                    disabled={!inputText.trim() || !isConnected}
                    className={`px-6 py-3 rounded-xl text-sm font-bold transition-all duration-300 flex items-center justify-center ${
                      inputText.trim() && isConnected
                        ? "bg-brand-green text-[#0B1120] shadow-lg shadow-brand-green/20 hover:bg-brand-green-light"
                        : "bg-white/5 text-text-muted cursor-not-allowed"
                    }`}
                  >
                    Send
                  </button>
                </form>
              </div>
            </>
          ) : (
            /* No contact selected placeholder */
            <div className="flex flex-col items-center justify-center h-full gap-4">
              <div className="w-16 h-16 rounded-full bg-white/5 border border-white/10 flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" strokeWidth={1} stroke="currentColor" className="w-8 h-8 text-text-muted">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z" />
                </svg>
              </div>
              <p className="text-sm text-text-muted font-medium">Select a conversation</p>
              <p className="text-xs text-text-muted/50">Choose a contact from the left panel to start chatting</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
