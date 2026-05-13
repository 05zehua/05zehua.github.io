const TARGET_URL = "https://05zehua.github.io/#data=";

chrome.action.onClicked.addListener(async tab => {
  if (!tab.id) return;

  if (!/^https:\/\/jw\.ustc\.edu\.cn\//.test(tab.url || "")) {
    await showAlert(tab.id, "请先打开 jw.ustc.edu.cn 的考试信息页面，再点击插件。");
    return;
  }

  let results;
  try {
    results = await chrome.scripting.executeScript({
      target: { tabId: tab.id, allFrames: true },
      func: extractExamsFromPage
    });
  } catch (error) {
    await showAlert(tab.id, "读取页面失败，请确认已打开考试信息页面。");
    return;
  }

  const exams = results
    .flatMap(item => Array.isArray(item.result) ? item.result : [])
    .filter(item => item.courseName || item.datetime || item.location || item.note);

  if (exams.length === 0) {
    await showAlert(tab.id, "没有找到考试表格。请确认已进入“考试信息”页面，并等待页面加载完成。");
    return;
  }

  const url = TARGET_URL + encodeURIComponent(JSON.stringify(exams));
  await chrome.tabs.create({ url });
});

async function showAlert(tabId, message) {
  try {
    await chrome.scripting.executeScript({
      target: { tabId },
      func: msg => alert(msg),
      args: [message]
    });
  } catch {}
}

function extractExamsFromPage() {
  let table = document.querySelector("#exams");

  if (!table) {
    table = [...document.querySelectorAll("table")].find(candidate => {
      const headers = [...candidate.querySelectorAll("th")]
        .map(th => th.innerText.trim())
        .join("|");

      return headers.includes("课程名称")
        && headers.includes("日期时间")
        && headers.includes("考场");
    });
  }

  if (!table) return [];

  return [...table.querySelectorAll("tbody tr")]
    .map(row => {
      const cells = [...row.querySelectorAll("td")].map(td => td.innerText.trim());

      return {
        courseName: cells[2] || "",
        datetime: cells[3] || "",
        location: [cells[6], cells[5], cells[4]].filter(Boolean).join(""),
        note: cells[7] || ""
      };
    })
    .filter(item => item.courseName || item.datetime || item.location || item.note);
}
