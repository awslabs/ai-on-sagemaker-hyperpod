import * as React from "react";
import { useState } from 'react';
import ContentLayout from "@cloudscape-design/components/content-layout";
import Box from "@cloudscape-design/components/box";
import Grid from "@cloudscape-design/components/grid";
import Container from "@cloudscape-design/components/container";
import SpaceBetween from "@cloudscape-design/components/space-between";
import Button from "@cloudscape-design/components/button";

export default function Home() {
    const [nextPage, setNextPage] = useState("#");
    const nextUrl = "#";

    return (
        <ContentLayout
            defaultPadding
            disableOverlap
            headerBackgroundStyle={(mode) =>
            `center center/cover url("/hero-header-${mode}.png")`
            }
            header={
            <Box padding={{ vertical: "xxxl" }}>
                <Grid gridDefinition={[{ colspan: { default: 12, s: 8 } }]}>
                <Container>
                    <Box padding="s">
                    <Box
                        fontSize="display-l"
                        fontWeight="bold"
                        variant="h1"
                        padding="n"
                    >
                        AI on Sagemaker Hyperpod
                    </Box>
                    <Box fontSize="display-l" fontWeight="light">
                        Optimized Blueprints for deploying high performance clusters
                        to train, fine tune, and host (inference) models on Amazon
                        Sagemaker Hyperpod
                    </Box>
                    <Box
                        variant="p"
                        color="text-body-secondary"
                        margin={{ top: "xs", bottom: "l" }}
                    >
                        <p>This is the home for all things related to Amazon Sagemaker
                        Hyperpod, built by the ML Frameworks team. We strive to
                        release content and assets that are based on our customer's
                        feedback and help them to improve their operational
                        efficiency. </p>
                        
                        <p>Explore practical examples, architectural
                        patterns, troubleshooting, and many other contents. Work
                        through running large distributed training jobs, fine
                        tuning, distillation, and preference alignment, using
                        frameworks such as PyTorch, JAX, NeMo, Ray, etc. We provide
                        examples for Meta's Llama, Amazon Nova, Mistral, DeepSeek,
                        and others. </p>
                        
                        <p>There are troubleshooting advise on specific
                        problems you may find, best practices when integrating with
                        other AWS services and open source projects, and code
                        snippets that you may find useful to incorporate on your
                        workloads.</p>
                    </Box>
                    <SpaceBetween direction="horizontal" size="xs">
                        <Button variant="link" onClick={(e) => setNextPage(e.detail.value)}>Blueprints</Button>
                        <Button variant="link" href="infrastructure">Infrastructure</Button>
                        <Button variant="link">Assets</Button>
                        <Button variant="link">Tools</Button>
                        <Button variant="link">Resources</Button>
                    </SpaceBetween>
                    </Box>
                </Container>
                </Grid>
            </Box>
            }
        />
    );
};
