import { useState, useEffect, useRef } from 'react';
import { sendMessage, getStarterQuestions } from '../lib/api';
import { marked } from 'marked';

interface Message {
  role: 'user' | 'assistant';
  text: string;
  loading?: boolean;
}

interface Props {
  accessToken?: string;
  athleteName?: string;
}

export default function ChatInterface({ accessToken: propToken, athleteName: propName }: Props) {
  const accessToken = propToken || localStorage.getItem('strava_access_token') || '';
  const athleteName = propName || localStorage.getItem('strava_athlete_name') || 'Runner';
  const [messages, setMessages] = useState<Message[]>([]);
  const [history, setHistory] = useState<any[]>([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [starters, setStarters] = useState<string[]>([]);
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    getStarterQuestions().then(setStarters);
  }, []);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  async function submit(text: string) {
    if (!text.trim() || loading) return;
    const userMsg: Message = { role: 'user', text };
    const loadingMsg: Message = { role: 'assistant', text: '', loading: true };
    setMessages(prev => [...prev, userMsg, loadingMsg]);
    setInput('');
    setLoading(true);

    try {
      const result = await sendMessage(text, history, accessToken);
      setHistory(result.conversation_history);
      setMessages(prev => [
        ...prev.slice(0, -1),
        { role: 'assistant', text: result.response },
      ]);
    } catch (err) {
      setMessages(prev => [
        ...prev.slice(0, -1),
        { role: 'assistant', text: 'Something went wrong. Check your connection and try again.' },
      ]);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Messages */}
      <div style={{ flex: 1, overflowY: 'auto', padding: '1.5rem', display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
        {messages.length === 0 && (
          <div className="welcome">
            <p className="welcome-label">Data coach</p>
            <h2>Ask the hard question, {athleteName.split(' ')[0]}.</h2>
            <p>Ask me anything about your training. I'll pull your real data before answering.</p>
            <div className="starters">
              {starters.map((q, i) => (
                <button key={i} className="starter-btn" onClick={() => submit(q)}>
                  {q}
                </button>
              ))}
            </div>
          </div>
        )}

        {messages.map((msg, i) => (
          <div key={i} className={`message ${msg.role}`}>
            {msg.loading ? (
              <div className="typing-indicator">
                <span /><span /><span />
              </div>
            ) : msg.role === 'assistant' ? (
              <div
                className="markdown"
                dangerouslySetInnerHTML={{ __html: marked.parse(msg.text) as string }}
              />
            ) : (
              <p>{msg.text}</p>
            )}
          </div>
        ))}
        <div ref={bottomRef} />
      </div>

      {/* Input */}
      <div className="input-bar">
        <input
          type="text"
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && submit(input)}
          placeholder="Ask about your training…"
          disabled={loading}
        />
        <button onClick={() => submit(input)} disabled={loading || !input.trim()}>
          {loading ? '…' : '↑'}
        </button>
      </div>

      <style>{`
        .welcome { padding: 1.5rem 0; color: var(--muted-foreground); }
        .welcome-label {
          color: var(--accent);
          font-family: "JetBrains Mono", monospace;
          font-size: .7rem;
          font-weight: 700;
          text-transform: uppercase;
          letter-spacing: .18em;
          margin-bottom: 1rem;
        }
        .welcome h2 {
          color: var(--foreground);
          font-size: clamp(2.5rem, 5vw, 4.5rem);
          line-height: .88;
          letter-spacing: -0.06em;
          text-transform: uppercase;
          margin: 0 0 1rem;
        }
        .welcome p { font-size: .95rem; line-height: 1.6; margin-bottom: 1.5rem; max-width: 26rem; }
        .starters { display: grid; gap: .85rem; margin: 0; }
        .starter-btn {
          appearance: none;
          background: transparent;
          border: 0;
          border-bottom: 1px solid var(--border);
          color: var(--foreground);
          padding: 0 0 .85rem;
          font-size: .82rem;
          cursor: pointer;
          transition: color 150ms cubic-bezier(.25,0,0,1), border-color 150ms cubic-bezier(.25,0,0,1);
          font-family: "JetBrains Mono", monospace;
          font-weight: 700;
          text-align: left;
          text-transform: uppercase;
          letter-spacing: .08em;
        }
        .starter-btn:hover { color: var(--accent); border-color: var(--accent); }

        .message { display: flex; max-width: 760px; width: 100%; }
        .message.user { justify-content: flex-end; margin-left: auto; }
        .message.assistant { justify-content: flex-start; }
        .message.user p {
          background: var(--accent);
          color: var(--accent-foreground);
          padding: .85rem 1rem;
          margin: 0;
          font-size: .9rem;
          max-width: 480px;
          font-weight: 700;
        }
        .message.assistant .markdown {
          border-left: 3px solid var(--accent);
          padding: .25rem 0 .25rem 1rem;
          font-size: .95rem;
          line-height: 1.7;
          max-width: 640px;
        }
        .markdown h1,.markdown h2,.markdown h3 {
          font-size: 1.4rem;
          line-height: 1;
          letter-spacing: -0.04em;
          text-transform: uppercase;
          margin: 1rem 0 .5rem;
        }
        .markdown strong { color: var(--accent); }
        .markdown ul { padding-left: 1.25rem; margin: .75rem 0; }
        .markdown p { margin: .75rem 0; }
        .markdown p:last-child { margin-bottom: 0; }

        .typing-indicator { display: flex; gap: 6px; padding: 1rem 0; }
        .typing-indicator span { width: 22px; height: 3px; background: var(--muted-foreground); animation: bounce 1.2s infinite; }
        .typing-indicator span:nth-child(2) { animation-delay: .2s; }
        .typing-indicator span:nth-child(3) { animation-delay: .4s; }
        @keyframes bounce { 0%,80%,100% { opacity: .35; } 40% { opacity: 1; } }

        .input-bar {
          display: flex;
          gap: .75rem;
          padding: 1rem 1.5rem 1.5rem;
          border-top: 1px solid var(--border);
          background: var(--background);
        }
        .input-bar input {
          flex: 1;
          min-width: 0;
          background: var(--input);
          border: 1px solid var(--border);
          color: var(--foreground);
          border-radius: 0;
          padding: .8rem 1rem;
          min-height: 48px;
          font-size: 1rem;
          outline: none;
          transition: border-color 150ms cubic-bezier(.25,0,0,1);
        }
        .input-bar input:focus { border-color: var(--accent); }
        .input-bar button {
          min-width: 48px;
          height: 48px;
          border-radius: 0;
          background: var(--foreground);
          color: var(--background);
          border: 1px solid var(--foreground);
          font-size: 1.15rem;
          cursor: pointer;
          transition: background 150ms cubic-bezier(.25,0,0,1), color 150ms cubic-bezier(.25,0,0,1), opacity 150ms cubic-bezier(.25,0,0,1);
          display: flex;
          align-items: center;
          justify-content: center;
          font-weight: 900;
        }
        .input-bar button:hover:not(:disabled) { background: var(--accent); color: var(--accent-foreground); border-color: var(--accent); }
        .input-bar button:disabled { opacity: .4; cursor: default; }
      `}</style>
    </div>
  );
}
