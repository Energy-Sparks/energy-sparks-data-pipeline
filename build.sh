#!/bin/sh
set -ex

mkdir -p build
docker build -t data-pipeline-ruby-layer -f Containerfile .
docker create --name data-pipeline-ruby-layer data-pipeline-ruby-layer
docker cp data-pipeline-ruby-layer:/ruby/build/ruby build
docker rm data-pipeline-ruby-layer

cd build
zip -9 -r ruby-layer.zip ruby

cd ..
zip -9 -r build/data-pipeline.zip handlers/**/*.rb handler.rb Gemfile Gemfile.lock