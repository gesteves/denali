'use strict';

var cheerio     = require('gulp-cheerio');
var gulp        = require('gulp');
var jshint      = require('gulp-jshint');
var jsstylish   = require('jshint-stylish');
var rename      = require('gulp-rename');
var rename      = require('gulp-rename');
var scsslint    = require('gulp-scss-lint');
var scssstylish = require('gulp-scss-lint-stylish');
var svgmin      = require('gulp-svgmin');
var replace     = require('gulp-replace');

var paths = {
  js: ['Gulpfile.js', 'app/assets/javascripts/**/*.js', '!app/assets/javascripts/vendors/*.js'],
  svg: ['app/assets/images/svg/*.svg'],
  sass: ['app/assets/stylesheets/**/*.scss', '!app/assets/stylesheets/vendors/*.scss']
};

// Lint JS
gulp.task('js', function () {
  return gulp.src(paths.js)
    .pipe(jshint())
    .pipe(jshint.reporter(jsstylish));
});

// Lint Sass
gulp.task('sass', function() {
  return gulp.src(paths.sass)
    .pipe(scsslint({
      config: '.scss-lint.yml',
      bundleExec: true,
      customReport: scssstylish
    }));
});

// Minify and concatenate SVGs
// and save as a Rails partial
gulp.task('svg', function () {
  return gulp.src(paths.svg)
    .pipe(svgmin())
    .pipe(cheerio({
      run: function ($) {
        $('[style]').removeAttr('style');
        $('[fill]').removeAttr('fill');
        $('[stroke]').removeAttr('stroke');
      },
      parserOptions: { xmlMode: true }
    }))
    .pipe(cheerio({
      run: function ($) {
        $('svg').attr({
          'class': '{{{%= svg_class %}}}'
        });
        $('svg').removeAttr('xmlns');
      },
      parserOptions: { xmlMode: true }
    }))
    .pipe(replace('{{{', '<'))
    .pipe(replace('}}}', '>'))
    .pipe(rename({ extname: '.html.erb', prefix: '_' }))
    .pipe(gulp.dest('app/views/partials/svg'));
});

gulp.task('watch', function () {
  gulp.watch(paths.js, ['js']);
  gulp.watch(paths.svg, ['svg']);
  gulp.watch(paths.sass, ['sass']);
});

gulp.task('default', ['watch']);
