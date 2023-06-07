namespace :deploy do

  def build_with_docker
    system 'bundle config set --local deployment "true"' # Set bundler configuration to deployment mode
    system 'bundle config set --local path "."'
    system 'bundle config set without "test development"'
    system 'docker run --platform linux/amd64 --rm -it ' +
           '-v $PWD:/var/gem_build ' +
           '-w /var/gem_build ' +
           '-e BUNDLE_SILENCE_ROOT_WARNING=1 ' +
           'amazon/aws-sam-cli-build-image-ruby2.7 ' +
           'bundle install'
    system 'bundle config unset deployment'
    system 'bundle config unset path'
    system 'bundle config unset without'
  end

  task :development do
    system 'rm -Rf ruby'
    if build_with_docker
      system 'sls deploy --stage development'
    end
  end

  task :test do
    system 'rm -Rf ruby'
    if build_with_docker
      system 'sls deploy --stage test'
    end
  end

  task :production do
    system 'rm -Rf ruby'
    if build_with_docker
      system 'sls deploy --stage production'
    end
  end
end
