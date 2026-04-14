import React, { useState, useEffect, useRef } from 'react';
import styles from './styles.module.css';

interface Stat {
  value: number;
  label: string;
  suffix?: string;
  prefix?: string;
}

interface StatsCounterProps {
  stats: Stat[];
  duration?: number;
}

const StatsCounter: React.FC<StatsCounterProps> = ({ stats, duration = 2000 }) => {
  const [counts, setCounts] = useState<number[]>(stats.map(() => 0));
  const [hasAnimated, setHasAnimated] = useState(false);
  const counterRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting && !hasAnimated) {
          setHasAnimated(true);

          // Animate each counter
          stats.forEach((stat, index) => {
            const startTime = Date.now();
            const startValue = 0;
            const endValue = stat.value;

            const animate = () => {
              const currentTime = Date.now();
              const elapsed = currentTime - startTime;
              const progress = Math.min(elapsed / duration, 1);

              // Easing function for smooth animation
              const easeOutQuad = (t: number) => t * (2 - t);
              const easedProgress = easeOutQuad(progress);

              const currentValue = Math.floor(startValue + (endValue - startValue) * easedProgress);

              setCounts((prevCounts) => {
                const newCounts = [...prevCounts];
                newCounts[index] = currentValue;
                return newCounts;
              });

              if (progress < 1) {
                requestAnimationFrame(animate);
              }
            };

            requestAnimationFrame(animate);
          });
        }
      },
      { threshold: 0.3 }
    );

    if (counterRef.current) {
      observer.observe(counterRef.current);
    }

    return () => {
      if (counterRef.current) {
        observer.unobserve(counterRef.current);
      }
    };
  }, [stats, duration, hasAnimated]);

  const formatNumber = (num: number): string => {
    return num.toLocaleString();
  };

  return (
    <div ref={counterRef} className={styles.statsContainer}>
      {stats.map((stat, index) => (
        <div key={index} className={styles.statItem}>
          <div className={styles.statValue}>
            {stat.prefix || ''}
            {formatNumber(counts[index])}
            {stat.suffix || ''}
          </div>
          <div className={styles.statLabel}>{stat.label}</div>
        </div>
      ))}
    </div>
  );
};

export default StatsCounter;
