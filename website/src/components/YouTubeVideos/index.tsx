import type { ReactNode } from 'react';
import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

type VideoItem = {
  id: string;
  title: string;
  description: ReactNode;
  videoId: string; // YouTube video ID
};

const VideoList: VideoItem[] = [
  {
    id: 'video1',
    title: 'Accelerate FM pre-training on Amazon SageMaker HyperPod (Amazon EKS)',
    videoId: 'mYiZOYlpoO0', // Placeholder - replace with actual YouTube video ID
    description: (
      <>
        Amazon SageMaker HyperPod is purpose-built to reduce time to train foundation models (FMs) by up to 40% and scale across more than a thousand AI accelerators efficiently. 
        In this video, learn about Amazon EKS support in SageMaker HyperPod to accelerate your FM training.
        <br />
        Learn more at: <a href="https://go.aws/3TUKZSs">https://go.aws/3TUKZSs</a>
      </>
    ),
  },
  {
    id: 'video2',
    title: 'Accelerate FM pre-training on Amazon SageMaker HyperPod (Slurm)',
    videoId: 'aP6kok1yPMM', // Placeholder - replace with actual YouTube video ID
    description: (
      <>
        Amazon SageMaker HyperPod is purpose-built to reduce time to train foundation models (FMs) by up to 40% and scale across more than a thousand AI accelerators efficiently. 
        In this video, dive into how to run distributed training on SageMaker HyperPod.
        <br />
        Learn more at: <a href="https://go.aws/3TUKZSs">https://go.aws/3TUKZSs</a>
      </>
    ),
  },
  {
    id: 'video3',
    title: 'Get started with Amazon SageMaker HyperPod flexible training plans',
    videoId: 'Itcw8zhdArY', // Placeholder - replace with actual YouTube video ID
    description: (
      <>
        Amazon SageMaker HyperPod helps you scale and accelerate generative AI model development. 
        In this video, you will learn how to use the flexible training plans feature to run efficient model training that aligns with your timelines and budgets.
        <br />
        Learn more about Amazon SageMaker HyperPod - <a href="https://go.aws/3WwsBA3">https://go.aws/3WwsBA3</a>
      </>
    ),
  },
];

function VideoItem({ title, description, videoId, isReversed }: VideoItem & { isReversed: boolean }) {
  return (
    <div className={clsx('row', styles.videoRow, { [styles.videoRowReversed]: isReversed })}>
      <div className={clsx('col col--6', styles.videoContainer)}>
        <div className={styles.videoWrapper}>
          <iframe
            className={styles.videoIframe}
            src={`https://www.youtube.com/embed/${videoId}`}
            title={title}
            frameBorder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowFullScreen
          />
        </div>
      </div>
      <div className={clsx('col col--6', styles.descriptionContainer)}>
        <div className={styles.descriptionContent}>
          <Heading as="h3" className={styles.videoTitle}>
            {title}
          </Heading>
          <p className={styles.videoDescription}>{description}</p>
        </div>
      </div>
    </div>
  );
}

export default function YouTubeVideos(): ReactNode {
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
        {VideoList.map((video, idx) => (
          <VideoItem
            key={video.id}
            {...video}
            isReversed={idx % 2 === 1} // Alternate layout: even indices (0,2) = left video, odd indices (1) = right video
          />
        ))}
      </div>
    </section>
  );
}