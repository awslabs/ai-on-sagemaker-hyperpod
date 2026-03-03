import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

const config: Config = {
  title: 'AI on SageMaker HyperPod',
  tagline: 'Optimized Blueprints for deploying high performance clusters to train, fine tune, and host (inference) models on Amazon SageMaker HyperPod',
  favicon: 'img/Amazon-Sagemaker-Icon.jpg',

  // Future flags, see https://docusaurus.io/docs/api/docusaurus-config#future
  future: {
    v4: true, // Improve compatibility with the upcoming Docusaurus v4
  },

  // Set the production url of your site here
  url: 'https://awslabs.github.io/',
  // Set the /<baseUrl>/ pathname under which your site is served
  // For GitHub pages deployment, it is often '/<projectName>/'
  baseUrl: '/ai-on-sagemaker-hyperpod/',

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
      {
        name: 'keywords',
        content: 'machine learning, generative ai, genai, sagemaker, hyperpod, SageMaker HyperPod, \
        model training, model inference, nemo framework, pytorch, pytorch framework'
      },
    ],
    // Replace with your project's social card
    image: 'img/header_background.png',
    // you can add an announcement bar on top of the navigation header
    //announcementBar: {
    //  id: 'new_feature',
    //  content: 'SageMaker HyperPod just announced a new feature! Check it out <a target="_blank" rel="noopener noreferrer" href="#">here</a>.',
    //  backgroundColor: '#fafbfc',
    //  textColor: '#091E42',
    //  isCloseable: true, 
    //},
    navbar: {
      title: 'AI on SageMaker HyperPod',
      logo: {
        alt: 'AI on SageMaker HyperPod',
        src: 'img/Amazon-Sagemaker-Icon.jpg',
      },
      hideOnScroll: false,
      items: [
        {
          to: '/docs/Introduction',
          label: 'Introduction',
          position: 'left',
        },
        {
          type: 'dropdown',
          label: 'EKS Orchestration',
          position: 'left',
          items: [
            {
              to: '/docs/eks-orchestration/getting-started/',
              label: 'Getting Started',
            },
            {
              to: '/docs/category/training-and-fine-tuning',
              label: 'Training & Fine-Tuning',
            },
            {
              to: '/docs/category/inference',
              label: 'Inference',
            },
            {
              to: '/docs/category/add-ons',
              label: 'Add-Ons',
            },
            {
              to: '/docs/category/integrations',
              label: 'Integrations',
            },
            {
              to: '/docs/eks-helpful-advice',
              label: 'Helpful Advice',
            },
            {
              to: '/docs/eks-validation-and-testing',
              label: 'Validation and Testing',
            },
          ],
        },
        {
          type: 'dropdown',
          label: 'SLURM Orchestration',
          position: 'left',
          items: [
            {
              to: '/docs/slurm-orchestration/getting-started/',
              label: 'Getting Started',
            },
            {
              to: '/docs/category/training-and-fine-tuning-1',
              label: 'Training & Fine-Tuning',
            },
            {
              to: '/docs/category/add-ons-1',
              label: 'Add-Ons',
            },
            {
              to: '/docs/slurm-helpful-advice',
              label: 'Helpful Advice',
            },
            {
              to: '/docs/slurm-validation-and-testing',
              label: 'Validation and Testing',
            },
          ],
        },
        {
          type: 'dropdown',
          label: 'Common Resources',
          position: 'left',
          items: [
            {
              to: '/docs/common/troubleshooting-guide',
              label: 'Troubleshooting Guide',
            },
            {
              to: '/docs/common-helpful-advice',
              label: 'Helpful Advice',
            },
            {
              to: '/docs/common-validation-and-testing',
              label: 'Validation and Testing',
            },
            {
              to: '/docs/category/infrastructure-as-a-code',
              label: 'Infrastructure as a Code',
            },
          ],
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
              to: '/docs/eks-orchestration/getting-started/',
            },
            {
              label: 'Orchestrated by SLURM',
              to: '/docs/slurm-orchestration/getting-started/',
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
              label: 'SageMaker HyperPod Recipes',
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
              label: 'Amazon SageMaker HyperPod',
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
      additionalLanguages: ['bash', 'shell-session', 'docker', 'ini', 'powershell'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
