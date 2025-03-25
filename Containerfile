FROM public.ecr.aws/sam/build-ruby3.2:latest-x86_64
# FROM public.ecr.aws/sam/build-ruby3.2:latest-arm64
RUN mkdir /ruby
WORKDIR /ruby
COPY Gemfile Gemfile.lock .
ENV BUNDLE_FORCE_RUBY_PLATFORM=true
ENV BUNDLE_WITHOUT=test:development
ENV BUNDLE_PATH=build
RUN bundle install
CMD "/bin/bash"
