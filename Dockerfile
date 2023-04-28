FROM drecom/ubuntu-ruby:2.6.0

# Install dependencies
RUN apt-get update -qq && \
  apt-get install -y haskell-platform nginx
	# apt-get install -y build-essential libpq-dev nodejs tzdata libgeos-dev

WORKDIR /usr/src/app

COPY . .
RUN bundle install

EXPOSE 80

CMD ["./Seeker/bin/build.sh"]
CMD ["ruby bin/build.rb"]

CMD ["./bin/server"]
