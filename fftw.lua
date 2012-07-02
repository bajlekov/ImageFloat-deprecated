--[[
	Copyright (C) 2011-2012 G. Bajlekov

    ImageFloat is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ImageFloat is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local ffi = require("ffi")
local p, fftw = pcall(loadlib, "fftw3")
assert(p, fftw)

--os.execute([=[echo '#include <fftw3.h>' > stub.c]=])
--os.execute([=[gcc -I /usr/include/SDL -E stub.c | grep -v '^#' > FFTW.h]=])

ffi.cdef(io.open('FFTW.h', 'r'):read('*a')) --contains stdio, interfering with sdl
io.close()

--[[
ffi.cdef[[
enum fftw_r2r_kind_do_not_use_me {
     FFTW_R2HC=0, FFTW_HC2R=1, FFTW_DHT=2,
     FFTW_REDFT00=3, FFTW_REDFT01=4, FFTW_REDFT10=5, FFTW_REDFT11=6,
     FFTW_RODFT00=7, FFTW_RODFT01=8, FFTW_RODFT10=9, FFTW_RODFT11=10
};
struct fftw_iodim_do_not_use_me {
     int n;
     int is;
     int os;
};
typedef long int ptrdiff_t;
typedef int wchar_t;
struct fftw_iodim64_do_not_use_me {
     ptrdiff_t n;
     ptrdiff_t is;
     ptrdiff_t os;
};
typedef double fftw_complex[2];
typedef struct fftw_plan_s *fftw_plan;
typedef struct fftw_iodim_do_not_use_me fftw_iodim;
typedef struct fftw_iodim64_do_not_use_me fftw_iodim64;
typedef enum fftw_r2r_kind_do_not_use_me fftw_r2r_kind;
extern void fftw_execute(const fftw_plan p);
extern fftw_plan fftw_plan_dft(int rank, const int *n, fftw_complex *in, fftw_complex *out, int sign, unsigned flags);
extern fftw_plan fftw_plan_dft_1d(int n, fftw_complex *in, fftw_complex *out, int sign, unsigned flags);
extern fftw_plan fftw_plan_dft_2d(int n0, int n1, fftw_complex *in, fftw_complex *out, int sign, unsigned flags);
extern fftw_plan fftw_plan_dft_3d(int n0, int n1, int n2, fftw_complex *in, fftw_complex *out, int sign, unsigned flags);
extern fftw_plan fftw_plan_many_dft(int rank, const int *n, int howmany, fftw_complex *in, const int *inembed, int istride, int idist, fftw_complex *out, const int *onembed, int ostride, int odist, int sign, unsigned flags);
extern fftw_plan fftw_plan_guru_dft(int rank, const fftw_iodim *dims, int howmany_rank, const fftw_iodim *howmany_dims, fftw_complex *in, fftw_complex *out, int sign, unsigned flags);
extern fftw_plan fftw_plan_guru_split_dft(int rank, const fftw_iodim *dims, int howmany_rank, const fftw_iodim *howmany_dims, double *ri, double *ii, double *ro, double *io, unsigned flags);
extern fftw_plan fftw_plan_guru64_dft(int rank, const fftw_iodim64 *dims, int howmany_rank, const fftw_iodim64 *howmany_dims, fftw_complex *in, fftw_complex *out, int sign, unsigned flags);
extern fftw_plan fftw_plan_guru64_split_dft(int rank, const fftw_iodim64 *dims, int howmany_rank, const fftw_iodim64 *howmany_dims, double *ri, double *ii, double *ro, double *io, unsigned flags);
extern void fftw_execute_dft(const fftw_plan p, fftw_complex *in, fftw_complex *out);
extern void fftw_execute_split_dft(const fftw_plan p, double *ri, double *ii, double *ro, double *io);
extern fftw_plan fftw_plan_many_dft_r2c(int rank, const int *n, int howmany, double *in, const int *inembed, int istride, int idist, fftw_complex *out, const int *onembed, int ostride, int odist, unsigned flags);
extern fftw_plan fftw_plan_dft_r2c(int rank, const int *n, double *in, fftw_complex *out, unsigned flags);
extern fftw_plan fftw_plan_dft_r2c_1d(int n,double *in,fftw_complex *out,unsigned flags);
extern fftw_plan fftw_plan_dft_r2c_2d(int n0, int n1, double *in, fftw_complex *out, unsigned flags);
extern fftw_plan fftw_plan_dft_r2c_3d(int n0, int n1, int n2, double *in, fftw_complex *out, unsigned flags);
extern fftw_plan fftw_plan_many_dft_c2r(int rank, const int *n, int howmany, fftw_complex *in, const int *inembed, int istride, int idist, double *out, const int *onembed, int ostride, int odist, unsigned flags);
extern fftw_plan fftw_plan_dft_c2r(int rank, const int *n, fftw_complex *in, double *out, unsigned flags);
extern fftw_plan fftw_plan_dft_c2r_1d(int n,fftw_complex *in,double *out,unsigned flags);
extern fftw_plan fftw_plan_dft_c2r_2d(int n0, int n1, fftw_complex *in, double *out, unsigned flags);
extern fftw_plan fftw_plan_dft_c2r_3d(int n0, int n1, int n2, fftw_complex *in, double *out, unsigned flags);
extern fftw_plan fftw_plan_guru_dft_r2c(int rank, const fftw_iodim *dims, int howmany_rank, const fftw_iodim *howmany_dims, double *in, fftw_complex *out, unsigned flags);
extern fftw_plan fftw_plan_guru_dft_c2r(int rank, const fftw_iodim *dims, int howmany_rank, const fftw_iodim *howmany_dims, fftw_complex *in, double *out, unsigned flags);
extern fftw_plan fftw_plan_guru_split_dft_r2c( int rank, const fftw_iodim *dims, int howmany_rank, const fftw_iodim *howmany_dims, double *in, double *ro, double *io, unsigned flags);
extern fftw_plan fftw_plan_guru_split_dft_c2r( int rank, const fftw_iodim *dims, int howmany_rank, const fftw_iodim *howmany_dims, double *ri, double *ii, double *out, unsigned flags);
extern fftw_plan fftw_plan_guru64_dft_r2c(int rank, const fftw_iodim64 *dims, int howmany_rank, const fftw_iodim64 *howmany_dims, double *in, fftw_complex *out, unsigned flags);
extern fftw_plan fftw_plan_guru64_dft_c2r(int rank, const fftw_iodim64 *dims, int howmany_rank, const fftw_iodim64 *howmany_dims, fftw_complex *in, double *out, unsigned flags);
extern fftw_plan fftw_plan_guru64_split_dft_r2c( int rank, const fftw_iodim64 *dims, int howmany_rank, const fftw_iodim64 *howmany_dims, double *in, double *ro, double *io, unsigned flags);
extern fftw_plan fftw_plan_guru64_split_dft_c2r( int rank, const fftw_iodim64 *dims, int howmany_rank, const fftw_iodim64 *howmany_dims, double *ri, double *ii, double *out, unsigned flags);
extern void fftw_execute_dft_r2c(const fftw_plan p, double *in, fftw_complex *out);
extern void fftw_execute_dft_c2r(const fftw_plan p, fftw_complex *in, double *out);
extern void fftw_execute_split_dft_r2c(const fftw_plan p, double *in, double *ro, double *io);
extern void fftw_execute_split_dft_c2r(const fftw_plan p, double *ri, double *ii, double *out);
extern fftw_plan fftw_plan_many_r2r(int rank, const int *n, int howmany, double *in, const int *inembed, int istride, int idist, double *out, const int *onembed, int ostride, int odist, const fftw_r2r_kind *kind, unsigned flags);
extern fftw_plan fftw_plan_r2r(int rank, const int *n, double *in, double *out, const fftw_r2r_kind *kind, unsigned flags);
extern fftw_plan fftw_plan_r2r_1d(int n, double *in, double *out, fftw_r2r_kind kind, unsigned flags);
extern fftw_plan fftw_plan_r2r_2d(int n0, int n1, double *in, double *out, fftw_r2r_kind kind0, fftw_r2r_kind kind1, unsigned flags);
extern fftw_plan fftw_plan_r2r_3d(int n0, int n1, int n2, double *in, double *out, fftw_r2r_kind kind0, fftw_r2r_kind kind1, fftw_r2r_kind kind2, unsigned flags);
extern fftw_plan fftw_plan_guru_r2r(int rank, const fftw_iodim *dims, int howmany_rank, const fftw_iodim *howmany_dims, double *in, double *out, const fftw_r2r_kind *kind, unsigned flags);
extern fftw_plan fftw_plan_guru64_r2r(int rank, const fftw_iodim64 *dims, int howmany_rank, const fftw_iodim64 *howmany_dims, double *in, double *out, const fftw_r2r_kind *kind, unsigned flags);
extern void fftw_execute_r2r(const fftw_plan p, double *in, double *out);
extern void fftw_destroy_plan(fftw_plan p); extern void fftw_forget_wisdom(void);
extern void fftw_cleanup(void); extern void fftw_set_timelimit(double);
extern void fftw_plan_with_nthreads(int nthreads);
extern int fftw_init_threads(void);
extern void fftw_cleanup_threads(void);
extern void fftw_export_wisdom_to_file(FILE *output_file);
extern char *fftw_export_wisdom_to_string(void);
extern void fftw_export_wisdom(void (*write_char)(char c, void *), void *data);
extern int fftw_import_system_wisdom(void);
extern int fftw_import_wisdom_from_file(FILE *input_file);
extern int fftw_import_wisdom_from_string(const char *input_string);
extern int fftw_import_wisdom(int (*read_char)(void *), void *data);
extern void fftw_fprint_plan(const fftw_plan p, FILE *output_file);
extern void fftw_print_plan(const fftw_plan p);
extern void *fftw_malloc(size_t n);
extern void fftw_free(void *p);
extern void fftw_flops(const fftw_plan p, double *add, double *mul, double *fmas);
extern double fftw_estimate_cost(const fftw_plan p);
extern const char fftw_version[];
extern const char fftw_cc[];
extern const char fftw_codelet_optim[];
]]
--]]

fft = {}
fft.fftw=fftw

fft.FORWARD = -1
fft.INVERSE = 1
fft.PLAN = {[0]=2^6, 0, 2^5, 2^3}

function fft.createPlan(n, p_in, p_out, forward, real, plan)
     pln = plan or fft.PLAN[0]
     local sign = forward and fft.FORWARD or fft.INVERSE
     if real==true then
          if sign==fft.FORWARD then
               return fftw.fftw_plan_dft_r2c_1d(n, p_in, p_out, plan)
          elseif sign==fft.INVERSE then
               return fftw.fftw_plan_dft_c2r_1d(n, p_in, p_out, plan)
          end
     elseif real==false then
          return fftw.fftw_plan_dft_1d(n, p_in, p_out, sign, plan)
     end
end

function fft.executePlan(plan)
     fftw.fftw_execute(plan)
end

function fft.destroyPlan(plan)
     fftw.fftw_destroy_plan(plan)
end

function fft.createBuffer(size)
     return ffi.cast("fftw_complex*", fftw.fftw_malloc(ffi.sizeof("fftw_complex")*size))
end

function fft.destroyBuffer(buffer)
     fftw.fftw_free(buffer)
end

return fft