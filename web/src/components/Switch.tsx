import s from './Switch.module.css';

// On/off switch (design: DeskApp settings, 52×30, bordo when on).
export default function Switch({ on, onChange, label }: { on: boolean; onChange: (v: boolean) => void; label: string }) {
  return (
    <button role="switch" aria-checked={on} aria-label={label} className={on ? `${s.sw} ${s.on}` : s.sw} onClick={() => onChange(!on)}>
      <span />
    </button>
  );
}
