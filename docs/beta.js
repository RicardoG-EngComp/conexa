(function () {
  "use strict";

  var form = document.getElementById("betaForm");
  var search = document.getElementById("courseSearch");
  var hiddenCourse = document.getElementById("courseValue");
  var list = document.getElementById("courseList");
  var status = document.getElementById("status");
  var submitBtn = document.getElementById("submitBtn");
  var frame = document.getElementById("submitFrame");
  var endpoint = (window.CONEXA_BETA_ENDPOINT || "").trim();

  var courses = [];
  var filtered = [];
  var selected = "";
  var activeIndex = -1;
  var submitting = false;

  function normalize(value) {
    return (value || "")
      .toLowerCase()
      .normalize("NFD")
      .replace(/[\u0300-\u036f]/g, "");
  }

  function setStatus(message, kind) {
    status.textContent = message || "";
    status.className = "status" + (kind ? " " + kind : "");
  }

  function closeList() {
    list.style.display = "none";
    search.setAttribute("aria-expanded", "false");
  }

  function renderList(query) {
    var term = normalize(query);
    filtered = courses.filter(function (course) {
      return !term || normalize(course).indexOf(term) >= 0;
    });
    activeIndex = -1;
    list.innerHTML = "";

    if (!filtered.length) {
      var empty = document.createElement("li");
      empty.textContent = "Nenhum curso encontrado.";
      empty.setAttribute("aria-disabled", "true");
      list.appendChild(empty);
      list.style.display = "block";
      search.setAttribute("aria-expanded", "true");
      return;
    }

    filtered.forEach(function (course, index) {
      var item = document.createElement("li");
      item.textContent = course;
      item.setAttribute("role", "option");
      item.dataset.index = String(index);
      item.addEventListener("mousedown", function (event) {
        event.preventDefault();
        choose(course);
      });
      list.appendChild(item);
    });
    list.style.display = "block";
    search.setAttribute("aria-expanded", "true");
  }

  function choose(course) {
    selected = course;
    search.value = course;
    hiddenCourse.value = course;
    setStatus("", "");
    closeList();
  }

  function highlight(index) {
    var items = list.querySelectorAll("li[role='option']");
    items.forEach(function (item) {
      item.classList.remove("active");
    });
    if (index < 0 || index >= items.length) {
      activeIndex = -1;
      return;
    }
    activeIndex = index;
    items[index].classList.add("active");
    items[index].scrollIntoView({ block: "nearest" });
  }

  function validate() {
    var name = (form.elements.name.value || "").trim();
    var ufvEmail = (form.elements.ufv_email.value || "").trim();
    var gmail = (form.elements.gmail.value || "").trim();
    var campus = form.elements.campus.value;
    var gender = form.elements.gender.value;
    var emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    var ufvPattern = /^[^\s@]+@(alunos\.ufv\.br|ufv\.br)$/i;

    if (!name) return "Informe seu nome completo.";
    if (!ufvPattern.test(ufvEmail)) {
      return "Use seu email institucional @alunos.ufv.br ou @ufv.br.";
    }
    if (!emailPattern.test(gmail)) {
      return "Informe uma conta Google válida para o Firebase.";
    }
    if (!hiddenCourse.value || courses.indexOf(hiddenCourse.value) < 0) {
      return "Selecione seu curso na lista.";
    }
    if (!campus) return "Selecione o campus.";
    if (!form.elements.age.checked ||
        !form.elements.android.checked ||
        !form.elements.four_weeks.checked) {
      return "Confirme os requisitos do beta.";
    }
    if (!gender) return "Selecione como você se identifica.";
    if (!form.elements.consent_independent.checked ||
        !form.elements.consent_firebase.checked ||
        !form.elements.consent_privacy.checked) {
      return "Aceite os consentimentos para continuar.";
    }
    if ((form.elements.website.value || "").trim()) {
      return "Não foi possível enviar.";
    }
    return "";
  }

  search.addEventListener("focus", function () {
    renderList(search.value);
  });

  search.addEventListener("input", function () {
    if (search.value !== selected) {
      selected = "";
      hiddenCourse.value = "";
    }
    renderList(search.value);
  });

  search.addEventListener("keydown", function (event) {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      if (list.style.display === "none") renderList(search.value);
      highlight(Math.min(activeIndex + 1, filtered.length - 1));
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      highlight(Math.max(activeIndex - 1, 0));
    } else if (event.key === "Enter" && activeIndex >= 0) {
      event.preventDefault();
      choose(filtered[activeIndex]);
    } else if (event.key === "Escape") {
      closeList();
    }
  });

  search.addEventListener("blur", function () {
    window.setTimeout(function () {
      closeList();
      if (selected) search.value = selected;
    }, 150);
  });

  document.addEventListener("click", function (event) {
    if (!event.target.closest(".combo")) closeList();
  });

  form.addEventListener("submit", function (event) {
    var error = validate();
    if (error) {
      event.preventDefault();
      setStatus(error, "error");
      return;
    }
    if (!endpoint) {
      event.preventDefault();
      setStatus(
        "Formulário em configuração. Envie um email para conexa.projeto@gmail.com.",
        "error"
      );
      return;
    }

    setStatus("Enviando inscrição...", "");
    submitBtn.disabled = true;
    submitting = true;
    form.action = endpoint;
  });

  frame.addEventListener("load", function () {
    if (!submitting) return;
    submitting = false;
    setStatus(
      "Inscrição recebida. A seleção considera a ordem de resposta e o equilíbrio da amostra. Se aprovado, enviaremos o link no Gmail informado.",
      "success"
    );
    submitBtn.textContent = "Inscrição enviada";
  });

  fetch("courses.json")
    .then(function (response) {
      if (!response.ok) throw new Error("courses");
      return response.json();
    })
    .then(function (data) {
      courses = Array.isArray(data) ? data.slice().sort(function (a, b) {
        return a.localeCompare(b, "pt-BR");
      }) : [];
      hiddenCourse.value = "";
      if (!courses.length) {
        setStatus("Lista de cursos indisponível.", "error");
      }
    })
    .catch(function () {
      setStatus("Não foi possível carregar a lista de cursos.", "error");
    });

  if (!endpoint) {
    setStatus(
      "Formulário ainda não configurado. O envio será liberado após a publicação do backend.",
      "error"
    );
  }
})();
