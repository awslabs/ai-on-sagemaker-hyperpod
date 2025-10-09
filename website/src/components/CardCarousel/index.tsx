import type { ReactNode } from 'react';
import React from 'react';
import clsx from 'clsx';
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
        {/* Placeholder Image */}
        <div className={styles.cardImagePlaceholder}>
          <svg width="120" height="80" viewBox="0 0 120 80" fill="none" xmlns="http://www.w3.org/2000/svg">
            <rect width="120" height="80" rx="8" fill={`hsl(${index * 60}, 70%, 60%)`} fillOpacity="0.1" stroke={`hsl(${index * 60}, 70%, 60%)`} strokeWidth="2" />
            <circle cx="60" cy="40" r="12" fill={`hsl(${index * 60}, 70%, 60%)`} fillOpacity="0.3" />
            <rect x="30" y="55" width="60" height="4" rx="2" fill={`hsl(${index * 60}, 70%, 60%)`} fillOpacity="0.4" />
            <rect x="40" y="62" width="40" height="3" rx="1.5" fill={`hsl(${index * 60}, 70%, 60%)`} fillOpacity="0.3" />
            {/* Image icon */}
            <path d="M45 25h30v20H45z" fill="none" stroke={`hsl(${index * 60}, 70%, 60%)`} strokeWidth="1.5" />
            <circle cx="52" cy="32" r="3" fill={`hsl(${index * 60}, 70%, 60%)`} fillOpacity="0.6" />
            <path d="m48 42 8-6 6 4 8-6v8H48v-2z" fill={`hsl(${index * 60}, 70%, 60%)`} fillOpacity="0.4" />
          </svg>
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

  const placeholderCards = [
    {
      title: "Amazon SageMaker HyperPod now supports custom AMIs",
      description: "Deploy clusters with pre-configured, security-hardened environments that meet organizational requirements. Custom AMIs enable faster startup times and consistent configurations across cluster nodes.",
      articleLink: "https://aws.amazon.com/about-aws/whats-new/2025/08/sagemaker-hyperpod-support-custom-ami/"
    },
    {
      title: "Announcing Managed Tiered Checkpointing for Amazon SageMaker HyperPodTraining Best Practices",
      description: "Train reliably on large-scale clusters with configurable checkpoint frequency across in-memory and persistent storage. Integrated with PyTorch's Distributed Checkpoint for easy implementation.",
      articleLink: "https://aws.amazon.com/about-aws/whats-new/2025/09/managed-tiered-checkpointing-amazon-sagemaker-hyperpod/"
    },
    {
      title: "Amazon SageMaker HyperPod now supports autoscaling using Karpenter",
      description: "Automatically scale clusters to meet dynamic inference and training demands. Managed node autoscaling eliminates Karpenter setup overhead while providing integrated resilience and fault tolerance.",
      articleLink: "https://aws.amazon.com/about-aws/whats-new/2025/09/sagemaker-hyperpod-autoscaling/"
    },
    {
      title: "Amazon SageMaker AI now supports P6e-GB200 UltraServers",
      description: "Deliver 20x compute and 11x memory performance with 360 petaflops of FP8 compute and 13.4 TB HBM3e memory. Combined with SageMaker's managed infrastructure and monitoring capabilities.",
      articleLink: "https://aws.amazon.com/about-aws/whats-new/2025/08/sagemaker-p6e-gb200-ultraservers/"
    },
  ];

  // Auto-switch cards every 5 seconds
  React.useEffect(() => {
    const interval = setInterval(() => {
      setActiveCard((prev) => (prev + 1) % placeholderCards.length);
    }, 5000);

    return () => clearInterval(interval);
  }, [placeholderCards.length]);

  return (
    <div className={styles.carouselContainer}>
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