FROM ruby:3.3

WORKDIR /site

COPY Gemfile Gemfile.lock ./

RUN gem install bundler -v 4.0.6 \
  && bundle install

EXPOSE 4030

CMD ["bundle", "exec", "jekyll", "serve", "--host", "0.0.0.0", "--port", "4030"]
