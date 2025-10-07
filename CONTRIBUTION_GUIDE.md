# Contribution Guide

Thank you! If you've opened this guide, you're probably looking to help contribute to AI on Sagemaker HyperPod. We really appreciate
you taking the time to help this project. To that end, we've written this guide to help you in your contributions so
that the PR process goes by a lot smoother as well as to remind ourselves of all the things we need to keep in mind when
we make changes to this repository.

## General Contributions

A few things to keep in mind when contributing anything to this repository:

1) Open a Github issue first: before committing code, please open a Github issue describing your proposed changes so we
   can provide guidance and avoid duplicate work.
2) Make sure your code renders properly locally. Instructions on how to test locally can be found under each contribution section.
  

## Contributing Blueprints

Blueprints are used to highlight specific examples. They run an end-to-end showcase of deploying a model training, inference, distillation etc,
running the example on SageMaker HyperPod. Where possible, new blueprints should reuse existing
architectures. Contributing blueprints generally requires:

1) New code
2) Documentation

The code should live in the [awsome-distributed-training](https://github.com/aws-samples/awsome-distributed-training) repository under the appropriate category.
Documentation will take the reader through a step-by-step process of how to execute the example. These should go in
`website/docs/` under the appropriate category.

Before you commit that contribution, make sure you understand the following: 
- We use the [Docusaurus](https://docusaurus.io) framework
- Contributions must be tested before creating a pull request. Instructions on test locally can be found below.

To test your changes locally, please follow the instructions below:
```bash
cd website
npm ci 
npm run build
npm run serve
```

If your build ran succesfully and the new contribution renders correctly, then make sure you have the `build/` and the `.docusaurus/` added to your `.gitignore` file or delete both before adding the files and pushing them. Your contribution should add only the files that you have changed, not the build files.

## Other Contributions

Other contributions are also very much desired. We are looking for benchmarks, best-practices, educational material.
These may require a case-by-case discussion, but will generally fall directly in the `website` folder somewhere.
