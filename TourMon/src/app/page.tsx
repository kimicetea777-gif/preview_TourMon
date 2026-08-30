import type { Metadata } from "next";
import localFont from "next/font/local";
import Link from "next/link";
import { landingContent } from "@/content/home/landing";

// 앱의 "그림책/스케치" 테마(TourMon_App/lib/config/sketch/sketch_theme.dart)와 같은 Gaegu 폰트.
// 소개 페이지에서만 쓰므로 layout.tsx(전역)가 아니라 여기서 로드 — 약관/개인정보 등 다른 페이지는
// 기존 Geist 유지.
const gaegu = localFont({
  src: [
    { path: "./fonts/Gaegu-Regular.ttf", weight: "400", style: "normal" },
    { path: "./fonts/Gaegu-Bold.ttf", weight: "700", style: "normal" },
  ],
  variable: "--font-gaegu",
  display: "swap",
});

const contactEmail = process.env.CONTACT_EMAIL;

export const metadata: Metadata = {
  title: `${landingContent.appName} — ${landingContent.tagline}`,
  description: landingContent.intro[0],
};

export default function Home() {
  const { appName, tagline, notice, intro, features, screenshots, help, footer } =
    landingContent;

  return (
    <div className={`landing ${gaegu.variable}`}>
      <header className="landing-header">
        <Link href="/" className="landing-brand">
          <img src="/logo.png" alt="" width={32} height={32} />
          <span>{appName}</span>
        </Link>
      </header>

      <main className="landing-main">
        <header className="landing-hero">
          <h1>{appName}</h1>
          <p className="landing-tagline">{tagline}</p>
        </header>

        <aside className="landing-notice" role="note">
          {notice.lines.map((line, index) => (
            <p key={index}>{line}</p>
          ))}
          <p>
            {notice.store.url ? (
              <a
                href={notice.store.url}
                target="_blank"
                rel="noopener noreferrer"
              >
                {notice.store.name}에서 다운로드
              </a>
            ) : (
              `${notice.store.name}에서 다운로드할 수 있습니다.`
            )}
          </p>
        </aside>

        <section className="landing-intro">
          {intro.map((paragraph, index) => (
            <p key={index}>{paragraph}</p>
          ))}
        </section>

        <section className="landing-shots" aria-label="구동 화면">
          {screenshots.map((shot) => (
            <figure key={shot.src}>
              {/* 이미지는 public/screenshots/ 에 넣을 것 — 없으면 alt 텍스트만 노출됨 */}
              <img src={shot.src} alt={shot.alt} loading="lazy" />
              <figcaption>{shot.caption}</figcaption>
            </figure>
          ))}
        </section>

        <section className="landing-features">
          <ul>
            {features.map((feature) => (
              <li key={feature.title}>
                <h2>{feature.title}</h2>
                <p>{feature.body}</p>
              </li>
            ))}
          </ul>
        </section>

        <section className="landing-help">
          <p>{help.prompt}</p>
          <Link className="landing-help-cta" href={help.href}>
            {help.cta}
          </Link>
        </section>
      </main>

      <footer className="landing-footer">
        <nav>
          {footer.links.map((link) => (
            <Link key={link.href} href={link.href}>
              {link.label}
            </Link>
          ))}
        </nav>
        {contactEmail && (
          <p className="landing-footer-contact">
            {footer.contactLabel}{" "}
            <a href={`mailto:${contactEmail}`}>{contactEmail}</a>
          </p>
        )}
        <p className="landing-footer-copy">
          © {new Date().getFullYear()} {appName}
        </p>
      </footer>
    </div>
  );
}
