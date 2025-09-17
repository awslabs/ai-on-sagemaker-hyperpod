import type {ReactNode} from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  Svg: React.ComponentType<React.ComponentProps<'svg'>>;
  description: ReactNode;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'Resilient',
    Svg: require('@site/static/img/resilience.svg').default,
    description: (
      <>
        Proactively screen health of inbound nodes. 
        Continuous cluster hardware monitoring. 
        Automated repair and job resumption. 
        Spare capacity dedicated to self-healing.
      </>
    ),
  },
  {
    title: 'Scalable',
    Svg: require('@site/static/img/scalability.svg').default,
    description: (
      <>
        Single-spine node topology.
        Pre-configured EFA for optimal inter-node communication speeds.
        Flexible paths to securing compute capacity.
        Rapid cluster scale-up without performanc degradation.
      </>
    ),
  },
  {
    title: 'Versatile',
    Svg: require('@site/static/img/versatility.svg').default,
    description: (
      <>
        Broad Generative AI software stack compatibility -- with extensive collection of examples.
        Lifecycle scripts or Helm charts for streamlined cluster customization.
        Support for a variety of top accelerator instances such as UltraServers, Trn2, P6-B200, P5en, P5, P4de, etc.
      </>
    ),
  },
  {
    title: 'Efficient',
    Svg: require('@site/static/img/efficiency.svg').default,
    description: (
      <>
        Task Governance maximizes cluster utilization.
        Integrated Sagemaker AI tools and libraries.
        Recipes for starting FM training in minutes.
        Hyperpod-managed DLAMI include version-compatible drivers, toolkits, and libraries.
      </>
    ),
  },
];

function Feature({title, Svg, description}: FeatureItem) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <Svg className={styles.featureSvg} role="img" />
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h2">{title}</Heading>
        <p>{description}</p>
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
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
