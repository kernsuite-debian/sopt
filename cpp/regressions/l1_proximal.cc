#include <algorithm>
#include <catch.hpp>
#include <complex>
#include <numeric>
#include <random>
#include <type_traits>

#include "sopt_prox.h"
#include "tools_for_tests/cdata.h"
#include "sopt/l1_proximal.h"

std::random_device rd;
std::default_random_engine rengine(rd());

template <class T>
sopt::Matrix<T> concatenated_permutations(sopt::t_uint i, sopt::t_uint j) {
  std::vector<size_t> cols(j);
  std::iota(cols.begin(), cols.end(), 0);
  std::shuffle(cols.begin(), cols.end(), rengine);

  assert(j % i == 0);
  auto const N = j / i;
  auto const elem = 1e0 / std::sqrt(static_cast<typename sopt::real_type<T>::type>(N));
  sopt::Matrix<T> result = sopt::Matrix<T>::Zero(i, cols.size());
  for (typename sopt::Matrix<T>::Index k(0); k < result.cols(); ++k) result(cols[k] / N, k) = elem;
  return result;
}

template <class SCALAR>
sopt::Vector<SCALAR> c_proximal(sopt::proximal::L1<SCALAR> const &l1,
                                typename sopt::real_type<SCALAR>::type gamma,
                                sopt::Vector<SCALAR> const &x, bool pos = false, bool tf = false) {
  using namespace sopt;
  typedef typename sopt::real_type<SCALAR>::type Real;
  int const nr = (l1.Psi().adjoint() * x).size();
  Vector<Real> weights = l1.weights();
  if (l1.weights().size() == 1) weights = l1.weights()(1) * Vector<Real>::Ones(nr);
  CData<SCALAR> const psi_data{nr, x.size(), l1.Psi(), 0, 0};
  sopt_prox_l1param params = {
      0,                               // verbosity
      static_cast<int>(l1.itermax()),  // max iter
      l1.tolerance(),                  // relative change
      l1.nu(),                         // nu
      tf ? 1 : 0,                      // tight frame
      pos ? 1 : 0                      // Positivity constraints
  };
  Vector<SCALAR> xin = x;
  Vector<SCALAR> result = Vector<SCALAR>::Zero(x.size());
  Vector<SCALAR> dummy = Vector<SCALAR>::Zero(nr);
  Vector<SCALAR> sol = Vector<SCALAR>::Zero(x.size());
  Vector<SCALAR> u = Vector<SCALAR>::Zero(nr);
  Vector<SCALAR> v = Vector<SCALAR>::Zero(nr);
  sopt_prox_l1(static_cast<void *>(result.data()), static_cast<void *>(xin.data()), x.size(), nr,
               &direct_transform<SCALAR>, (void **)&psi_data, &adjoint_transform<SCALAR>,
               (void **)&psi_data, weights.data(), gamma, std::is_same<SCALAR, Real>::value ? 1 : 0,
               params, static_cast<void *>(dummy.data()), static_cast<void *>(sol.data()),
               static_cast<void *>(u.data()), static_cast<void *>(v.data()));
  return result;
}

TEST_CASE("Compare L1 proximals", "") {
  using namespace sopt;
  typedef std::complex<double> Scalar;

  auto l1 = proximal::L1<Scalar>();
  Vector<Scalar> const input = Vector<Scalar>::Random(15);

  SECTION("Check tight frame") {
    auto const Psi = concatenated_permutations<Scalar>(input.size(), input.size() * 10);
    auto const weights = Vector<t_real>::Random(Psi.cols()).array().abs().matrix().eval();
    auto const gamma = 1e0 / static_cast<t_real>(weights.size());
    l1.Psi(Psi).weights(weights).tolerance(1e-12).itermax(10000);
    auto const cpp = l1.tight_frame(gamma, input);
    auto const c = c_proximal(l1, gamma, input, false, true);
    CHECK(cpp.isApprox(c));
  }
  SECTION("Check general case") {
    auto const Psi = Matrix<Scalar>::Random(input.size(), input.size() * 10).eval();
    auto const weights = Vector<t_real>::Random(Psi.cols()).array().abs().matrix().eval();
    auto const gamma = 1e0 / static_cast<t_real>(weights.size());

    SECTION("No constraints") {
      for (auto i : {2, 10, 25, 500, 1000}) {
        l1.Psi(Psi).weights(weights).tolerance(1e-12).itermax(i - 1);
        auto const c = c_proximal(l1, gamma, input, false, false);
        auto const cpp = l1.itermax(i)(gamma, input);
        CHECK(cpp.proximal.isApprox(c, 1e-8 * c.array().abs().maxCoeff()));
      }
    }

    SECTION("Positivity constraints") {
      for (auto i : {2, 10, 25, 500, 1000}) {
        l1.Psi(Psi).weights(weights).tolerance(1e-12).itermax(i - 1).positivity_constraint(true);
        auto const c = c_proximal(l1, gamma, input, true, false);
        auto const cpp = l1.itermax(i)(gamma, input);
        CAPTURE(c.transpose());
        CAPTURE(cpp.proximal.transpose());
        CHECK(cpp.proximal.isApprox(c, 1e-8 * c.array().abs().maxCoeff()));
      }
    }
  }
}
