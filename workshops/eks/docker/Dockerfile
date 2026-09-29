FROM public.ecr.aws/hpc-cloud/nccl-tests:cuda12.8.1-efa1.41.0-ofiv1.15.0-ncclv2.26.6-1-testsv2.15.2

WORKDIR /workspace

COPY train.py /workspace

COPY requirements.txt /workspace

RUN pip install -r requirements.txt