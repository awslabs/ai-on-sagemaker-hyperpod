import type { ReactNode } from 'react';
import { useEffect, useRef, useState } from 'react';
import clsx from 'clsx';
import useBaseUrl from '@docusaurus/useBaseUrl';
import Link from '@docusaurus/Link';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  Svg: React.ComponentType<React.ComponentProps<'svg'>>;
  description: ReactNode;
  link?: string;
};

// PNG Image component wrapper
function PngImageIcon({ src, alt }: { src: string; alt: string }) {
  return (
    <img
      src={useBaseUrl(src)}
      alt={alt}
      width="200"
      height="200"
      style={{ objectFit: 'contain' }}
    />
  );
}

const FeatureList: FeatureItem[] = [
  {
    title: 'Remove interruptions with a resilient development environment',
    Svg: () => <PngImageIcon src="/img/99-front-page/resilience-robot.png" alt="Resilient development environment" />,
    description: (
      <>
        Automatically detects, diagnoses, and recovers from infrastructure faults.
        Run model development workloads continuously for months without interruption
        through intelligent fault management and self-healing capabilities.
      </>
    ),
    link: '/docs/category/features',
  },
  {
    title: 'Efficiently scale and parallelize model training across thousands of AI accelerators',
    Svg: () => <PngImageIcon src="/img/99-front-page/scale-with-accelerators.png" alt="State-of-the-art performance" />,
    description: (
      <>
        Automatically splits models and datasets across AWS cluster instances for
        efficient scaling. Optimizes training jobs for AWS network infrastructure
        and cluster topology. Streamlines checkpointing with optimized frequency
        to minimize training overhead.
      </>
    ),
    link: '/docs/category/recipes',
  },
  {
    title: 'Achieve state-of-the-art performance with recipes and tools',
    Svg: () => <PngImageIcon src="/img/99-front-page/state-of-the-art.png" alt="State-of-the-art performance" />,
    description: (
      <>
        Pre-built recipes enable rapid training and fine-tuning of generative AI
        models in minutes. Customize Amazon Nova foundation models for business-specific
        use cases while maintaining industry-leading performance. Built-in experimentation
        and observability tools help enhance model performance across all skill levels.
      </>
    ),
    link: '/docs/category/recipes',
  },
  {
    title: 'Reduce costs with centralized governance over all model development tasks',
    Svg: () => <PngImageIcon src="/img/99-front-page/reduce-costs-governance.png" alt="State-of-the-art performance" />,
    description: (
      <>
        Provides full visibility and control over compute resource allocation for
        training and inference tasks. Automatically manages task queues, prioritizing
        critical work to meet deadlines and budgets. Efficient resource utilization
        reduces model development costs by up to 40%.
      </>
    ),
    link: '/docs/category/features',
  },
];

function Feature({ title, Svg, description, link, index }: FeatureItem & { index: number }) {
  const [isVisible, setIsVisible] = useState(false);
  const featureRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setIsVisible(true);
          }
        });
      },
      { threshold: 0.1 }
    );

    if (featureRef.current) {
      observer.observe(featureRef.current);
    }

    return () => {
      if (featureRef.current) {
        observer.unobserve(featureRef.current);
      }
    };
  }, []);

  return (
    <div
      ref={featureRef}
      className={clsx(
        'col col--3',
        styles.featureItem,
        isVisible && styles.featureVisible
      )}
      style={{
        '--stagger-delay': `${index * 0.1}s`,
      } as React.CSSProperties}
    >
      <div className={styles.gradientBorder}>
        <div className={styles.featureCard}>
          <div className="text--center">
            <Svg
              className={styles.featureSvg}
              role="img"
            />
          </div>
          <div className={clsx("text--center padding-horiz--md", styles.featureContent)}>
            <Heading as="h3" className={styles.featureTitle}>
              {title}
            </Heading>
            <div className={styles.featureDescription}>
              <p>{description}</p>
            </div>
            {link && (
              <Link to={link} className={styles.learnMoreLink}>
                Learn More <span className={styles.arrow}>→</span>
              </Link>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

export default function HomepageFeatures(): ReactNode {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} index={idx} />
          ))}
        </div>
      </div>
    </section>
  );
}
