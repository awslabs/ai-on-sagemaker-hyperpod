import type { ReactNode } from 'react';
import React from 'react';
import clsx from 'clsx';
import useBaseUrl from '@docusaurus/useBaseUrl';
import styles from './styles.module.css';

// Placeholder Card Component for Carousel
function PlaceholderCard({
  title,
  index,
  isActive,
  description,
  articleLink
}: {
  title: string;
  index: number;
  isActive: boolean;
  description: string;
  articleLink: string;
}) {
  return (
    <div
      className={clsx(styles.carouselCard, {
        [styles.carouselCardActive]: isActive
      })}
    >
      <div className={styles.cardContent}>
        {/* Card Image */}
        <div className={styles.cardImagePlaceholder}>
          <img
            src={useBaseUrl('/img/99-front-page/whats-news.webp')}
            alt={title}
            width="120"
            height="80"
          />
        </div>

        {/* Card Title */}
        <h4 className={styles.cardTitle}>{title}</h4>

        {/* Text Description */}
        <p className={styles.cardDescription}>
          {description}
        </p>

        {/* Article Link */}
        <a
          href={articleLink}
          className={styles.cardLink}
          onClick={(e) => e.stopPropagation()} // Prevent card click when clicking link
          target="_blank"
          rel="noopener noreferrer"
        >
          Read Article →
        </a>
      </div>
    </div>
  );
}

export default function CardCarousel(): ReactNode {
  const [activeCard, setActiveCard] = React.useState(0);
  const [isPaused, setIsPaused] = React.useState(false);
  const [touchStart, setTouchStart] = React.useState(0);
  const [touchEnd, setTouchEnd] = React.useState(0);

  const placeholderCards = [
    {
      title: "Scaling seismic foundation models on AWS with SageMaker HyperPod",
      description: "TGS achieved near-linear scaling for distributed training and expanded context windows using HyperPod, reducing training time from 6 months to 5 days while analyzing larger seismic volumes.",
      articleLink: "https://aws.amazon.com/blogs/machine-learning/scaling-seismic-foundation-models-on-aws-distributed-training-with-amazon-sagemaker-hyperpod-and-expanding-context-windows/"
    },
    {
      title: "Accelerating AI model production at Hexagon with SageMaker HyperPod",
      description: "Hexagon partnered with AWS to scale AI model production by pretraining state-of-the-art segmentation models using SageMaker HyperPod's model training infrastructure.",
      articleLink: "https://aws.amazon.com/blogs/machine-learning/accelerating-ai-model-production-at-hexagon-with-amazon-sagemaker-hyperpod/"
    },
    {
      title: "Checkpointless Training on Amazon SageMaker HyperPod",
      description: "A new training approach that reduces traditional checkpointing needs through peer-to-peer state recovery, achieving significant improvements in recovery speed and training efficiency on large GPU clusters.",
      articleLink: "https://aws.amazon.com/blogs/machine-learning/checkpointless-training-on-amazon-sagemaker-hyperpod-production-scale-training-with-faster-fault-recovery/"
    },
    {
      title: "Speed up cluster procurement with SageMaker HyperPod training plans",
      description: "Reserve accelerated compute capacity up to 8 weeks in advance with flexible scheduling options. Training plans help organizations access compute resources for LLM training more quickly.",
      articleLink: "https://aws.amazon.com/blogs/machine-learning/speed-up-your-cluster-procurement-time-with-amazon-sagemaker-hyperpod-training-plans/"
    },
  ];

  // Auto-switch cards every 3 seconds (pause on hover)
  React.useEffect(() => {
    if (isPaused) return;

    const interval = setInterval(() => {
      setActiveCard((prev) => (prev + 1) % placeholderCards.length);
    }, 3000);

    return () => clearInterval(interval);
  }, [placeholderCards.length, isPaused]);

  // Touch swipe handlers
  const handleTouchStart = (e: React.TouchEvent) => {
    setTouchStart(e.targetTouches[0].clientX);
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    setTouchEnd(e.targetTouches[0].clientX);
  };

  const handleTouchEnd = () => {
    if (!touchStart || !touchEnd) return;

    const distance = touchStart - touchEnd;
    const isLeftSwipe = distance > 50;
    const isRightSwipe = distance < -50;

    if (isLeftSwipe) {
      setActiveCard((prev) => (prev + 1) % placeholderCards.length);
    } else if (isRightSwipe) {
      setActiveCard((prev) => (prev - 1 + placeholderCards.length) % placeholderCards.length);
    }

    setTouchStart(0);
    setTouchEnd(0);
  };

  return (
    <div
      className={styles.carouselContainer}
      onMouseEnter={() => setIsPaused(true)}
      onMouseLeave={() => setIsPaused(false)}
      onTouchStart={handleTouchStart}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >
      <div className={styles.carouselScroll}>
        {placeholderCards.map((card, index) => (
          <PlaceholderCard
            key={index}
            title={card.title}
            description={card.description}
            articleLink={card.articleLink}
            index={index}
            isActive={activeCard === index}
          />
        ))}
      </div>
      {/* Navigation Bullets */}
      <div className={styles.carouselNavigation}>
        {placeholderCards.map((_, index) => (
          <button
            key={index}
            className={clsx(styles.carouselBullet, {
              [styles.carouselBulletActive]: index === activeCard
            })}
            onClick={() => setActiveCard(index)}
            aria-label={`Show card ${index + 1}`}
          />
        ))}
      </div>
    </div>
  );
}