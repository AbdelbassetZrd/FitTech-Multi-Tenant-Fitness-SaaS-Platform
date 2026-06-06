"use client";

import { useEffect, useRef, useState, useCallback } from "react";

const WS_URL = process.env.NEXT_PUBLIC_WS_URL || "ws://localhost:8000";

export interface ChatMessage {
  message: string;
  sender_id: string;
  sender_name: string;
  created_at: string;
  is_bot: boolean;
}

interface UseChatOptions {
  contactId: string | null;
  accessToken: string | null;
}

export function useChat({ contactId, accessToken }: UseChatOptions) {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isConnected, setIsConnected] = useState(false);
  const [isConnecting, setIsConnecting] = useState(false);

  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reconnectAttempt = useRef(0);
  const maxReconnects = 5;

  // Track the current contactId to avoid stale closures
  const contactIdRef = useRef(contactId);
  contactIdRef.current = contactId;

  const cleanup = useCallback(() => {
    if (reconnectTimer.current) {
      clearTimeout(reconnectTimer.current);
      reconnectTimer.current = null;
    }
    if (wsRef.current) {
      wsRef.current.onopen = null;
      wsRef.current.onmessage = null;
      wsRef.current.onerror = null;
      wsRef.current.onclose = null;
      if (wsRef.current.readyState === WebSocket.OPEN || wsRef.current.readyState === WebSocket.CONNECTING) {
        wsRef.current.close();
      }
      wsRef.current = null;
    }
    setIsConnected(false);
    setIsConnecting(false);
    reconnectAttempt.current = 0;
  }, []);

  const connect = useCallback(() => {
    if (!contactId || !accessToken) return;

    cleanup();
    setMessages([]);
    setIsConnecting(true);

    const url = `${WS_URL}/ws/chat/${contactId}/?token=${accessToken}`;
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      // Make sure we're still interested in this contact
      if (contactIdRef.current !== contactId) {
        ws.close();
        return;
      }
      setIsConnected(true);
      setIsConnecting(false);
      reconnectAttempt.current = 0;
    };

    ws.onmessage = (event) => {
      try {
        const data: ChatMessage = JSON.parse(event.data);
        // Filter out the "System" connected notice
        if (data.sender_id === "system") return;

        setMessages((prev) => {
          // Deduplicate by checking created_at + sender_id + message
          const isDup = prev.some(
            (m) =>
              m.created_at === data.created_at &&
              m.sender_id === data.sender_id &&
              m.message === data.message,
          );
          if (isDup) return prev;
          return [...prev, data];
        });
      } catch {
        // ignore non-JSON frames
      }
    };

    ws.onerror = () => {
      // onerror is always followed by onclose, so just let onclose handle it
    };

    ws.onclose = () => {
      setIsConnected(false);
      setIsConnecting(false);

      // Only reconnect if we're still looking at the same contact
      if (
        contactIdRef.current === contactId &&
        reconnectAttempt.current < maxReconnects
      ) {
        const delay = Math.min(1000 * 2 ** reconnectAttempt.current, 16000);
        reconnectAttempt.current += 1;
        reconnectTimer.current = setTimeout(() => {
          // Re-check before actually reconnecting
          if (contactIdRef.current === contactId) {
            setIsConnecting(true);
            const retryUrl = `${WS_URL}/ws/chat/${contactId}/?token=${accessToken}`;
            const retryWs = new WebSocket(retryUrl);
            wsRef.current = retryWs;

            retryWs.onopen = ws.onopen;
            retryWs.onmessage = ws.onmessage;
            retryWs.onerror = ws.onerror;
            retryWs.onclose = ws.onclose;
          }
        }, delay);
      }
    };
  }, [contactId, accessToken, cleanup]);

  // Connect whenever contactId changes
  useEffect(() => {
    if (contactId && accessToken) {
      connect();
    } else {
      cleanup();
      setMessages([]);
    }
    return cleanup;
  }, [contactId, accessToken, connect, cleanup]);

  const sendMessage = useCallback(
    (text: string) => {
      if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) return;
      wsRef.current.send(
        JSON.stringify({
          message: text,
          recipient_id: contactId,
        }),
      );
    },
    [contactId],
  );

  return { messages, sendMessage, isConnected, isConnecting };
}
