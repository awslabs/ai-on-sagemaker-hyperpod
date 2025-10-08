import type { ReactNode } from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';
import Layout from '@theme/Layout';
import HomepageFeatures from '@site/src/components/HomepageFeatures';
import YouTubeVideos from '@site/src/components/YouTubeVideos';
import Heading from '@theme/Heading';

import styles from './index.module.css';

function HomepageHeader() {
  const { siteConfig } = useDocusaurusContext();
  return (
    <header className={clsx('hero hero--primary', styles.heroBanner)}>
      <div className="container">
        <Heading as="h1" className="hero__title">
          {siteConfig.title}
        </Heading>
        <p className="hero__subtitle">{siteConfig.tagline}</p>
        <div className={styles.buttonImageLayout}>
          <Link
            className={clsx("button button--secondary button--lg", styles.squaredButton)}
            to="/docs/getting-started/orchestrated-by-eks/initial-cluster-setup">
            👩🏽‍💻 Orchestrated by EKS <br /><br />
            Blueprints & Getting Started guide
          </Link>
          <img
            src="img/central-intro-image.jpg"
            className={styles.centeredImage}
            alt="Amazon Sagemaker Hyperpod - the central infrastructure brain of your large distributed training jobs"
          />
          <Link
            className={clsx("button button--secondary button--lg", styles.squaredButton)}
            to="/docs/getting-started/orchestrated-by-slurm/initial-cluster-setup">
            👩🏽‍💻 Orchestrated by SLURM <br /><br />
            Blueprints & Getting Started guide
          </Link>
        </div>
      </div>
    </header>
  );
}

export default function Home(): ReactNode {
  const { siteConfig } = useDocusaurusContext();
  return (
    <Layout
      title={`${siteConfig.title}`}
      description="AI on Sagemaker Hyperpod - Optimized Blueprints for deploying high performance clusters to train, fine tune, and host (inference) models on Amazon Sagemaker Hyperpod">
      <HomepageHeader />
      <main>
        <HomepageFeatures />
        <YouTubeVideos />
      </main>
    </Layout>
  );
}
