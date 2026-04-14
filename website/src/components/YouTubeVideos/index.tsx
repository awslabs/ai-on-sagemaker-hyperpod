import type { ReactNode } from 'react';
import { useState } from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import VideoModal from '@site/src/components/VideoModal';
import styles from './styles.module.css';

type VideoItem = {
  id: string;
  title: string;
  description: ReactNode;
  videoId: string; // YouTube video ID
  duration?: string;
};

const VideoList: VideoItem[] = [
  {
    id: 'video1',
    title: 'Accelerate FM pre-training on Amazon SageMaker HyperPod (Amazon EKS)',
    videoId: 'mYiZOYlpoO0',
    duration: '3:45',
    description: (
      <>
        Amazon SageMaker HyperPod is purpose-built to reduce time to train foundation models (FMs) by up to 40% and scale across more than a thousand AI accelerators efficiently.
        In this video, learn about Amazon EKS support in SageMaker HyperPod to accelerate your FM training.
        <br />
        Learn more at: <a href="https://go.aws/3TUKZSs" target="_blank" rel="noopener noreferrer">https://go.aws/3TUKZSs</a>
      </>
    ),
  },
  {
    id: 'video2',
    title: 'Accelerate FM pre-training on Amazon SageMaker HyperPod (Slurm)',
    videoId: 'aP6kok1yPMM',
    duration: '4:12',
    description: (
      <>
        Amazon SageMaker HyperPod is purpose-built to reduce time to train foundation models (FMs) by up to 40% and scale across more than a thousand AI accelerators efficiently.
        In this video, dive into how to run distributed training on SageMaker HyperPod.
        <br />
        Learn more at: <a href="https://go.aws/3TUKZSs" target="_blank" rel="noopener noreferrer">https://go.aws/3TUKZSs</a>
      </>
    ),
  },
  {
    id: 'video3',
    title: 'Get started with Amazon SageMaker HyperPod flexible training plans',
    videoId: 'Itcw8zhdArY',
    duration: '5:28',
    description: (
      <>
        Amazon SageMaker HyperPod helps you scale and accelerate generative AI model development.
        In this video, you will learn how to use the flexible training plans feature to run efficient model training that aligns with your timelines and budgets.
        <br />
        Learn more about Amazon SageMaker HyperPod - <a href="https://go.aws/3WwsBA3" target="_blank" rel="noopener noreferrer">https://go.aws/3WwsBA3</a>
      </>
    ),
  },
];

function VideoThumbnail({
  title,
  description,
  videoId,
  duration,
  onClick
}: VideoItem & { onClick: () => void }) {
  // YouTube thumbnail URL
  const thumbnailUrl = `https://img.youtube.com/vi/${videoId}/maxresdefault.jpg`;

  return (
    <div
      className={styles.videoCard}
      onClick={onClick}
      role="button"
      tabIndex={0}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          onClick();
        }
      }}
      aria-label={`Play video: ${title}`}
    >
      <div className={styles.thumbnailContainer}>
        <img
          src={thumbnailUrl}
          alt={title}
          className={styles.thumbnail}
          loading="lazy"
        />
        <div className={styles.playButtonOverlay}>
          <svg className={styles.playIcon} viewBox="0 0 68 48" xmlns="http://www.w3.org/2000/svg">
            <path d="M66.52,7.74c-0.78-2.93-2.49-5.41-5.42-6.19C55.79,.13,34,0,34,0S12.21,.13,6.9,1.55 C3.97,2.33,2.27,4.81,1.48,7.74C0.06,13.05,0,24,0,24s0.06,10.95,1.48,16.26c0.78,2.93,2.49,5.41,5.42,6.19 C12.21,47.87,34,48,34,48s21.79-0.13,27.1-1.55c2.93-0.78,4.64-3.26,5.42-6.19C67.94,34.95,68,24,68,24S67.94,13.05,66.52,7.74z" fill="#f00"></path>
            <path d="M 45,24 27,14 27,34" fill="#fff"></path>
          </svg>
        </div>
        {duration && (
          <div className={styles.durationBadge}>
            {duration}
          </div>
        )}
      </div>
      <div className={styles.videoCardContent}>
        <Heading as="h3" className={styles.videoCardTitle}>
          {title}
        </Heading>
        <p className={styles.videoCardDescription}>{description}</p>
      </div>
    </div>
  );
}

export default function YouTubeVideos(): ReactNode {
  const [selectedVideo, setSelectedVideo] = useState<VideoItem | null>(null);

  const handleVideoClick = (video: VideoItem) => {
    setSelectedVideo(video);
  };

  const handleCloseModal = () => {
    setSelectedVideo(null);
  };

  return (
    <section className={styles.videosSection}>
      <div className="container">
        <div className={styles.sectionHeader}>
          <Heading as="h2" className="text--center">
            Learn with Video Tutorials
          </Heading>
          <p className="text--center">
            Watch these tutorials to master Amazon SageMaker HyperPod
          </p>
        </div>
        <div className={styles.videoGrid}>
          {VideoList.map((video) => (
            <VideoThumbnail
              key={video.id}
              {...video}
              onClick={() => handleVideoClick(video)}
            />
          ))}
        </div>
      </div>

      {selectedVideo && (
        <VideoModal
          videoId={selectedVideo.videoId}
          title={selectedVideo.title}
          isOpen={!!selectedVideo}
          onClose={handleCloseModal}
        />
      )}
    </section>
  );
}