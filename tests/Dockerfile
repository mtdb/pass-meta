FROM python:3.6-alpine

ENV PYTHONUNBUFFERED 1
ENV PYTHONDONTWRITEBYTECODE 1

RUN apk update
RUN apk add git
RUN apk add make
RUN apk add bash
RUN apk add gnupg

RUN git clone https://git.zx2c4.com/password-store
WORKDIR password-store
RUN make install

RUN pip install --upgrade pip
RUN pip install pytest

RUN pass init "Testing Password Storage Key"

WORKDIR /tests

CMD pytest
