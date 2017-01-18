FROM yastdevel/ruby
COPY . /usr/src/app
# a workaround to allow package building on a non-s390 machine
RUN sed -i "/^ExclusiveArch:/d" package/*.spec

