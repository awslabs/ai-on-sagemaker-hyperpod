import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'AI on Sagemaker Hyperpod',
  tagline: 'Optimized Blueprints for deploying high performance clusters to train, fine tune, and host (inference) models on Amazon Sagemaker Hyperpod',
  favicon: 'img/Amazon-Sagemaker-Icon.jpg',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: 'https://awslabs.github.io/',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/',

  // GitHub pages deployment config.
  // If you aren't using GitHub pages, you don't need these.
  organizationName: 'awslabs', // Usually your GitHub org/user name. Approved org: awslabs.
  projectName: 'ai-on-sagemaker-hyperpod', // Usually your repo name. 
  trailingSlash: false,
  deploymentBranch: 'gh-pages',
  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  // Even if you don't use internationalization, you can use this field to set
  // useful metadata like html lang. For example, if your site is Chinese, you
  // may want to replace "en" with "zh-Hans".
  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: './sidebars.ts',
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          //editUrl:
            //'https://github.com/facebook/docusaurus/tree/main/packages/create-docusaurus/templates/shared/',
        },
        blog: {
          showReadingTime: true,
          feedOptions: {
            type: ['rss', 'atom'],
            xslt: true,
          },
          // Please change this to your repo.
          // Remove this to remove the "edit this page" links.
          //editUrl:
            //'https://github.com/facebook/docusaurus/tree/main/packages/create-docusaurus/templates/shared/',
          // Useful options to enforce blogging best practices
          onInlineTags: 'warn',
          onInlineAuthors: 'warn',
          onUntruncatedBlogPosts: 'warn',
        },
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    colorMode: {
      defaultMode: 'dark',
    },
    docs: {
      sidebar: {
        hideable: true, // allow better focus on content on smaller screen sizes (ex: tablet, phones)
        autoCollapseCategories: true, // hide categories which are not focused on
      }
    },
    metadata: [
      { name: 'keywords', 
        content: 'machine learning, generative ai, genai, sagemaker, hyperpod, sagemaker hyperpod, \
        model training, model inference, nemo framework, pytorch, pytorch framework'
      },
    ],
    // Replace with your project's social card
    image: 'img/header_background.png',
    // you can add an announcement bar on top of the navigation header
    //announcementBar: {
    //  id: 'new_feature',
    //  content: 'Sagemaker Hyperpod just announced a new feature! Check it out <a target="_blank" rel="noopener noreferrer" href="#">here</a>.',
    //  backgroundColor: '#fafbfc',
    //  textColor: '#091E42',
    //  isCloseable: true, 
    //},
    navbar: {
      title: 'AI on Sagemaker Hyperpod',
      logo: {
        alt: 'AI on Sagemaker Hyperpod',
        src: 'img/Amazon-Sagemaker-Icon.jpg',
      },
      hideOnScroll: false,
      items: [
        {
          type: 'dropdown',
          label: 'Orchestrated by EKS',
          position: 'left',
          items: [
            {
              to: '/docs/getting-started/orchestrated-by-eks/initial-cluster-setup', 
              label: 'Initial cluster setup',
            },
            {
              to: '/docs/eks-blueprints/training/trainium/aws-trainium', 
              label: 'AWS Trainium',
            },
            {
              to: '/docs/eks-blueprints/training/ddp/distributed-data-parallel', 
              label: 'Distributed Data Parallel',
            },
            {
              to: '/docs/eks-blueprints/training/fsdp/fully-sharded-data-parallel', 
              label: 'Fully Sharded Data Parallel',
            },
            {
              to: '/docs/eks-blueprints/training/megatron-lm', 
              label: 'NVIDIA Megatron LM',
            },
            {
              to: '/docs/eks-blueprints/training/ray-train', 
              label: 'Ray Train',
            },
          ],
        },
        {
          type: 'dropdown',
          label: 'Orchestrated by SLURM',
          position: 'left',
          items: [
            {
              to: '/docs/getting-started/orchestrated-by-slurm/initial-cluster-setup', 
              label: 'Initial cluster setup',
            },
            {
              to: '/docs/slurm-blueprints/training/trainium/aws-trainium', 
              label: 'AWS Trainium',
            },
            {
              to: '/docs/slurm-blueprints/training/ddp/distributed-data-parallel', 
              label: 'Distributed Data Parallel',
            },
            {
              to: '/docs/slurm-blueprints/training/fsdp/fully-sharded-data-parallel', 
              label: 'Fully Sharded Data Parallel',
            },
            {
              to: '/docs/slurm-blueprints/training/megatron-lm', 
              label: 'NVIDIA Megatron LM',
            },
            {
              to: '/docs/slurm-blueprints/training/ray-train', 
              label: 'Ray Train',
            },
          ],
        },
        {
          to: '/resources', 
          label: 'Useful links', 
          position: 'left'
        },
        {
          href: 'https://github.com/awslabs/ai-on-sagemaker-hyperpod',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Docs',
          items: [
            {
              label: 'Orchestrated by EKS',
              to: '/docs/getting-started/orchestrated-by-eks/initial-cluster-setup',
            },
            {
              label: 'Orchestrated by SLURM',
              to: '/docs/getting-started/orchestrated-by-slurm/initial-cluster-setup',
            },
          ],
        },
        {
          title: 'Sites with Sagemaker AI content',
          items: [
            {
              label: 'Awsome Distributed Training',
              href: 'https://github.com/aws-samples/awsome-distributed-training',
            },
            {
              label: 'Sagemaker Hyperpod Recipes',
              href: 'https://github.com/aws/sagemaker-hyperpod-recipes',
            },
          ],
        },
        {
          title: 'Other AWS related sites',
          items: [
            {
              label: 'AWS Training & Certification',
              href: 'https://aws.training',
            },
            {
              label: 'Amazon Sagemaker Hyperpod',
              href: 'https://aws.amazon.com/sagemaker/ai/hyperpod',
            },
            {
              label: 'AWS re:Post',
              href: 'https://repost.aws',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} AWS WWSO ML Frameworks team. Built with ❤️ at AWS.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
