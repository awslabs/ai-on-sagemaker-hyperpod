import type { ReactNode } from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  Svg: React.ComponentType<React.ComponentProps<'svg'>>;
  description: ReactNode;
};

// Placeholder SVG component
function PlaceholderIcon({ color = '#2e8555' }: { color?: string }) {
  return (
    <svg width="150" height="150" viewBox="0 0 150 150" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width="150" height="150" rx="12" fill={color} fillOpacity="0.1" stroke={color} strokeWidth="2" />
      <circle cx="75" cy="60" r="20" fill={color} fillOpacity="0.3" />
      <rect x="45" y="90" width="60" height="8" rx="4" fill={color} fillOpacity="0.5" />
      <rect x="55" y="105" width="40" height="6" rx="3" fill={color} fillOpacity="0.3" />
    </svg>
  );
}

// PNG Image component wrapper
function PngImageIcon({ src, alt }: { src: string; alt: string }) {
  return (
    <img
      src={src}
      alt={alt}
      width="150"
      height="150"
      style={{ objectFit: 'contain' }}
    />
  );
}

const FeatureList: FeatureItem[] = [
  {
    title: 'Remove interruptions with a resilient development environment',
    Svg: () => <PngImageIcon src="/img/resilient.png" alt="Resilient development environment" />,
    description: (
      <>
        Automatically detects, diagnoses, and recovers from infrastructure faults.
        Run model development workloads continuously for months without interruption
        through intelligent fault management and self-healing capabilities.
      </>
    ),
  },
  {
    title: 'Efficiently scale and parallelize model training across thousands of AI accelerators',
    Svg: () => <PngImageIcon src="/img/scale.png" alt="State-of-the-art performance" />,
    description: (
      <>
        Automatically splits models and datasets across AWS cluster instances for
        efficient scaling. Optimizes training jobs for AWS network infrastructure
        and cluster topology. Streamlines checkpointing with optimized frequency
        to minimize training overhead.
      </>
    ),
  },
  {
    title: 'Achieve state-of-the-art performance with recipes and tools',
    Svg: () => <PngImageIcon src="/img/performance.png" alt="State-of-the-art performance" />,
    description: (
      <>
        Pre-built recipes enable rapid training and fine-tuning of generative AI
        models in minutes. Customize Amazon Nova foundation models for business-specific
        use cases while maintaining industry-leading performance. Built-in experimentation
        and observability tools help enhance model performance across all skill levels.
      </>
    ),
  },
  {
    title: 'Reduce costs with centralized governance over all model development tasks',
    Svg: () => <PngImageIcon src="/img/cost-v1.png" alt="State-of-the-art performance" />,
    description: (
      <>
        Provides full visibility and control over compute resource allocation for
        training and inference tasks. Automatically manages task queues, prioritizing
        critical work to meet deadlines and budgets. Efficient resource utilization
        reduces model development costs by up to 40%.
      </>
    ),
  },
];

function Feature({ title, Svg, description, index }: FeatureItem & { index: number }) {
  return (
    <div
      className={clsx('col col--3', styles.featureItem)}
      style={{
        animationDelay: `${index * 0.5}s`,
        '--hover-delay': `${index * 0.1}s`
      } as React.CSSProperties}
    >
      <div className="text--center">
        <Svg
          className={styles.featureSvg}
          role="img"
          style={{ animationDelay: `${index * 0.3}s` }}
        />
      </div>
      <div className={clsx("text--center padding-horiz--md", styles.featureContent)}>
        <Heading as="h3" className={styles.featureTitle}>
          {title}
        </Heading>
        <div className={styles.featureDescription}>
          <p>{description}</p>
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
