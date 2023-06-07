# Energy Sparks data pipeline

Data can be imported into Energy Sparks via files sent to specific email
addresses. Files attached to or linked to in emails can be either csv files,
xls or xlsx spreadsheets or zip files containing one or more of these types of
files.

The purpose of the pipeline is to convert these files to csv format, to
ultimately be added to the AMR data bucket, prefixed by the local part of the
email address they were sent to. There is an overnight batch job which
takes data from the AMR data bucket for importing to EnergySparks.

## Buckets and functions

There are a series of buckets which the files move through during processing.
An AWS lambda function is triggered by the addition of a file to a bucket,
which then processes the file and moves it onto another bucket which in turn
triggers more lambdas where required.

The buckets we have are as follows and there is a set of these for each of the
development, test and production environments:

**es-[env]-data-inbox**
Written to by SES email ruleset. Contains MIME formatted files.
Triggers running the “unpack attachments” function which will take attachments
and put them in the process bucket.

**es-[env]-data-process**
Contains files from emails that have been unpacked by the previous function.
Triggers running the "process file" function, which will put csv files
in the AMR data bucket, zip files in the uncompressed bucket or
spreadsheets in the spreadsheet bucket. Any unrecognised files are put in the
unprocessable bucket.

**es-[env]-data-uncompressed**
Contains files that need to be unzipped.
Triggers the "uncompress file" function, which unzips files and puts them in
the process bucket. Unregognised files are put in the unprocessable bucket.

**es-[env]-data-spreadsheet**
Contains spreadsheets that need to be converted to csv.
Triggers the "convert file" function which converts xls and xlsx spreadsheet
files to csv and puts them in the process bucket. Unregognised files are put in
the unprocessable bucket.

**es-[env]-data-unprocessable**
Contains files that cannot be processed, e.g. unknown formats, zips that
couldn’t be parsed or spreadsheets that couldn't be converted to csv.

**es-[env]-data-amr-data**
Contains CSV files ready for processing by the overnight batch job.
Within this bucket, folders called archive-* are archived versions of processed
files.

## Serverless

The setup of the buckets, lambdas and associated permissions is managed
by the [serverless](https://serverless.com/) framework which creates and
updates a CloudFormation stack on AWS.

Serverless allows us to set a 'stage' and run multiple environments
(e.g. test, production).

Serverless automatically creates the S3 buckets that are directly attached to
lambda functions in the `functions:` definitions. S3 buckets that are not
directly attached to lambda functions are specified in the `resources:`
section along with an S3 policy that allows SES to add to the `inbox` bucket.

The following instructions assume you are working from the
project root directory. Note, the region is set manually in the
serverless.yml file so deploying to different regions would require a
change to the configuration.

## Development and testing

Run `bundle install` to install the required gems locally.

Run `bundle exec rspec` to run the test suite. The tests stub calls
to the S3 service to monitor requests made and to fake responses.

Run `bundle exec guard` to run tests automatically as files change.

## Deployment configuration

Install serverless using homebrew (`brew install serverless`) or using
[npm](https://serverless.com/framework/docs/getting-started/).

Add the serverless AWS credentials to a profile called `serverless` in your
`~/.aws/credentials` file (these credentials can be found in a document titled
'Serverless AWS credentials' in 1password):

```
[serverless]
aws_access_key_id = YOURKEYHERE123
aws_secret_access_key = YOURSECRETHERE123
```

The functions log some errors in Rollbar. You need to add the following files:

```
.env.development
.env.test
.env.production
```

In each file, add a `ROLLBAR_ACCESS_TOKEN` environment variable - for test and
production, use the same token as the equivalent environments in the live main
application and for development, use the test environment token.

Make sure you have docker installed (for macOS `brew install --cask docker` or
[download the Apple Chip version](http://docker.com)).

## Deployment

As we are using ruby gems with native dependencies (i.e. Nokogiri), we use
Docker to build the Gems in an environment that is the same as AWS Lambda.
These can then be published to a lambda layer which is used by the functions.

To build the gems with docker but without deploying, run `rake deploy:build`.

If there is a permissions error when running docker, you may have to
[add your user to the docker group](https://linuxhandbook.com/docker-permission-denied/):
`sudo usermod -aG docker $USER`.

Run `rake deploy:ENVIRONMENT` to build the gems with docker and deploy the
pipeline to AWS. e.g. `rake deploy:development`.

Running `sls deploy` manually will deploy the `development` stage by default
but will skip building & packaging the gems.

To deploy to a different stage use the --stage option
e.g. `sls deploy --stage test`.

## Adding a new school area

The email rule for SES is a catch-all and will use the local part of the
email address to prefix the S3 object key. e.g. a file called
`import.csv` sent to `sheffield@test.com` will have the S3 key
`sheffield/import.csv`. Changes will need to be made to the main
application to process files from previously unseen prefixes.

## Adding a stage

To start receiving emails to a new stage a new SES rule will have to be
added to move the email to the `es-STAGE-data-pipeline-inbox` bucket.

## File expiry

File expiry is managed manually through the S3 web interface and will
need setting up for new buckets. This is done with lifecycle rules, configurable
via the Management tab for the bucket.

## Monitoring

Logs and usage stats found via the `Monitoring` tab on the individual
lambda AWS page.

## Further reading on deployment of gems with native extensions

[Building AWS Ruby Lambdas that Require Gems with Native Extension](https://dev.to/aws-builders/building-aws-ruby-lambdas-that-require-gems-with-native-extension-17h)
[Deploying ruby gems with native extensions on AWS Lambda & serverless](https://blog.francium.tech/deploying-ruby-gems-with-native-extensions-on-aws-lambda-using-the-serverless-toolkit-9079e34db2ab)