import React from 'react';
import { useState } from 'react';
import {
    AppLayoutToolbar,
    BreadcrumbGroup,
    Flashbar,
    HelpPanel,
    SideNavigation,
    SplitPanel,
} from '@cloudscape-design/components';
import { I18nProvider } from '@cloudscape-design/components/i18n';
import messages from '@cloudscape-design/components/i18n/messages/all.en';
import Home from './Home';

const LOCALE = 'en';

export default function AppLayoutToolbarPreview() {

    const [ActiveContent, setActiveContent] = useState(() => Home);
    const [activeBreadcrumb, setActiveBreadcrumb] = useState("Home");

    const switchContent = (e) => {
        setActiveContent(() => e)
    }

    return (
        <I18nProvider locale={LOCALE} messages={[messages]}>
        <AppLayoutToolbar
            disableContentPaddings={true}
            breadcrumbs={
            <BreadcrumbGroup
                items={[
                { text: 'AI on Sagemaker Hyperpod', href: '#' },
                { text: activeBreadcrumb, href: `#` },
                ]}
            />
            }
            navigationOpen={true}
            navigation={
            <SideNavigation
                header={{
                href: '#',
                text: 'Content',
                }}
                items={[
                    { type: 'link', text: `Home`, href: `#` },
                    { type: 'link', text: `Assets`, href: `#` },
                    { type: 'expandable-link-group', text: `Training Blueprints`, defaultExpanded: true, items: [
                            { type: 'link', text: `Fully Sharded Data Parallelism`, href: `#` },
                            { type: 'link', text: `Distributed Data Parallelism`, href: `#` },
                            { type: 'link', text: `Hyperpod Recipes`, href: `#` },
                            { type: 'link', text: `Megatron-LM`, href: `#` },
                            { type: 'link', text: `Ray-train`, href: `#` },
                        ] 
                    },
                    { type: 'expandable-link-group', text: `Fine Tuning Blueprints`, defaultExpanded: true, items: [
                            { type: 'link', text: `Parameter Efficient Fine Tuning (PEFT)`, href: `#` },
                            { type: 'link', text: `Policy Proxy Optimization (PPO)`, href: `#` },
                            { type: 'link', text: `Data Proxy Optimization (DPO)`, href: `#` },
                            { type: 'link', text: `Group Relative Policy Optimization (GRPO)`, href: `#` },
                            { type: 'link', text: `Low Rank Adaptation (LoRA)`, href: `#` },
                            { type: 'link', text: `Quantisized Low Rank Adaptation (QLoRA)`, href: `#` },
                        ] 
                    },
                    { type: 'expandable-link-group', text: `Infrastructure`, defaultExpanded: false, items: [
                        { type: 'link', text: `EKS - Setup`, href: `#` },
                        { type: 'link', text: `SLURM - Setup`, href: `#` }
                    ]},
                    { type: 'link', text: `Resources`, href: `#` },
                    { type: 'link', text: `Tools`, href: `#` }
                ]}
            />
            }
            notifications={
            <Flashbar
                items={[
                
                ]}
            />
            }
            toolsOpen={true}
            tools={<HelpPanel header={<h2>Overview</h2>}>Help content</HelpPanel>}
            content={<ActiveContent />}
            splitPanel={<SplitPanel header="Split panel header">Split panel content</SplitPanel>}
        />
        </I18nProvider>
    );
}