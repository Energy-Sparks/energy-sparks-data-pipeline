namespace :deploy do

  def build_with_docker
    system 'docker run --rm -it -v $PWD:/var/gem_build -w /var/gem_build amazon/aws-sam-cli-build-image-ruby2.7 bundle install --deployment --without test development --path=.'
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
