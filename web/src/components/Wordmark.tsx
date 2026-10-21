// "KAVIS / STUDY" logotype from the design: A and I in brand color, small star above the I.
export default function Wordmark({ size = 24 }: { size?: number }) {
  return (
    <span
      dir="ltr"
      style={{
        unicodeBidi: 'isolate',
        display: 'inline-flex',
        flexDirection: 'column',
        alignItems: 'center',
        gap: size * 0.14,
        lineHeight: 1,
        letterSpacing: 0,
      }}
    >
      <span style={{ fontSize: size, fontWeight: 700, letterSpacing: '.01em', color: 'var(--text)', whiteSpace: 'nowrap' }}>
        K<span style={{ color: 'var(--pb)' }}>A</span>V
        <span style={{ position: 'relative', color: 'var(--pb)' }}>
          I
          <svg
            viewBox="0 0 24 24"
            aria-hidden="true"
            style={{ position: 'absolute', left: '50%', top: '-.24em', width: '.34em', height: '.34em', transform: 'translateX(-50%)', overflow: 'visible' }}
          >
            <path d="M12 0 L14.6 9.4 L24 12 L14.6 14.6 L12 24 L9.4 14.6 L0 12 L9.4 9.4Z" fill="var(--pb)" />
          </svg>
        </span>
        S
      </span>
      <span style={{ fontSize: size * 0.55, fontWeight: 500, letterSpacing: '.1em', opacity: 0.7, color: 'var(--text)' }}>STUDY</span>
    </span>
  );
}
