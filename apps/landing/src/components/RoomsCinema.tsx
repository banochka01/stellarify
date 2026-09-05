import { useLayoutEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { Radio } from "lucide-react";

gsap.registerPlugin(ScrollTrigger);

export function RoomsCinema() {
  const root = useRef<HTMLDivElement>(null);

  useLayoutEffect(() => {
    const container = root.current;
    if (!container) return;
    const context = gsap.context(() => {
      const media = gsap.matchMedia();
      media.add(
        { reduce: "(prefers-reduced-motion: reduce)", desktop: "(min-width: 900px)" },
        ({ conditions }) => {
          const { reduce, desktop } = conditions as { reduce: boolean; desktop: boolean };
          const stage = container.querySelector<HTMLElement>(".cinema-stage");
          if (!stage) return;
          const avatars = Array.from(container.querySelectorAll<HTMLElement>(".room-mock-avatars span"));
          const progress = container.querySelector<HTMLElement>(".room-mock-progress span");
          const trackA = container.querySelector<HTMLElement>(".room-track-a");
          const trackB = container.querySelector<HTMLElement>(".room-track-b");
          const badge = container.querySelector<HTMLElement>(".room-sync");
          if (!progress || !trackA || !trackB || !badge) return;
          if (reduce) {
            gsap.set(avatars, { autoAlpha: 1, scale: 1 });
            gsap.set(progress, { width: "62%" });
            gsap.set(trackA, { autoAlpha: 0, y: -12 });
            gsap.set(trackB, { autoAlpha: 1, y: 0 });
            gsap.set(badge, { autoAlpha: 1, scale: 1 });
            return;
          }
          gsap.set(avatars, { autoAlpha: 0, scale: 0.4 });
          gsap.set(progress, { width: "0%" });
          gsap.set(trackB, { autoAlpha: 0, y: 12 });
          gsap.set(badge, { autoAlpha: 0, scale: 0.9 });
          const timeline = gsap.timeline({ paused: true, defaults: { ease: "power2.out" } });
          timeline.fromTo(avatars, { autoAlpha: 0, scale: 0.4 }, { autoAlpha: 1, scale: 1, duration: 0.5, stagger: 0.45, ease: "back.out(2)" }, 0.3);
          timeline.fromTo(progress, { width: "0%" }, { width: "62%", duration: 2.2, ease: "none" }, 0.6);
          timeline.to(trackA, { autoAlpha: 0, y: -12, duration: 0.5 }, 1.6);
          timeline.fromTo(trackB, { autoAlpha: 0, y: 12 }, { autoAlpha: 1, y: 0, duration: 0.5 }, 1.85);
          timeline.fromTo(badge, { autoAlpha: 0, scale: 0.9 }, { autoAlpha: 1, scale: 1, duration: 0.45, ease: "back.out(1.8)" }, 2.6);
          timeline.to({}, { duration: 0.6 });
          if (desktop) {
            ScrollTrigger.create({
              trigger: container,
              start: "top top",
              end: "bottom bottom",
              scrub: 0.6,
              animation: timeline
            });
          } else {
            ScrollTrigger.create({
              trigger: stage,
              start: "top 74%",
              once: true,
              onEnter: () => timeline.play()
            });
          }
        }
      );
      return () => media.revert();
    }, root);
    return () => context.revert();
  }, []);

  return (
    <div className="cinema-track cinema-track-rooms" ref={root}>
      <div className="cinema-stage">
        <div className="room-mock rooms-mock">
          <div className="room-mock-head">
            <span className="room-mock-live">В эфире</span>
            <span className="room-mock-members">4 слушателя</span>
          </div>
          <div className="room-tracks">
            <div className="room-track room-track-a">
              <span className="room-mock-cover" />
              <div>
                <p className="room-mock-title">Low Tide</p>
                <p className="room-mock-artist">Marén · SoundCloud</p>
              </div>
            </div>
            <div className="room-track room-track-b">
              <span className="room-mock-cover" />
              <div>
                <p className="room-mock-title">Стеклянный воздух</p>
                <p className="room-mock-artist">Полночь · Spotify</p>
              </div>
            </div>
          </div>
          <div className="room-mock-progress"><span /></div>
          <div className="room-mock-avatars">
            <span>МК</span>
            <span>АД</span>
            <span>ЛС</span>
            <span className="room-mock-you">Ты</span>
          </div>
          <p className="room-sync"><Radio size={15} /> Синхронизировано · задержка 12 мс</p>
        </div>
      </div>
    </div>
  );
}
