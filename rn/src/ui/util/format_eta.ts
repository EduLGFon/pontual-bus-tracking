// ETA formatting. Port of app/lib/ui/util/format_eta.dart.
import type { ArrivalVM } from "../models/arrival_vm";
import type { Certainty } from "../models/certainty";

export interface EtaFormat {
  primary: string;
  secondary: string;
  a11y: string;
}

function formatClock(d: Date): string {
  const h = String(d.getHours()).padStart(2, "0");
  const m = String(d.getMinutes()).padStart(2, "0");
  return `${h}:${m}`;
}

function isSameMinute(a: Date, b: Date): boolean {
  return a.getHours() === b.getHours() && a.getMinutes() === b.getMinutes() && a.getDate() === b.getDate();
}

function minutesUntilClock(at: Date, now: Date): number {
  const diff = Math.floor((at.getTime() - now.getTime()) / 60000);
  return diff;
}

function formatHours(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (m === 0) return `${h}h`;
  return `${h}h${m}`;
}

function minutesWord(n: number): string {
  return n === 1 ? "minuto" : "minutos";
}

export function formatEta(arrival: ArrivalVM, now: Date): EtaFormat {
  if (arrival.certainty === "stale") return staleFormat(arrival, now);
  if (arrival.certainty === "scheduled") return scheduledFormat(arrival, now);
  return freshFormat(arrival, now);
}

function freshFormat(arrival: ArrivalVM, now: Date): EtaFormat {
  const predicted = arrival.certainty === "predicted";
  const seconds = Math.floor((arrival.at.getTime() - now.getTime()) / 1000);
  const prefix = predicted ? "~" : "";
  if (seconds < 60) {
    return {
      primary: `${prefix}Agora`,
      secondary: "Chegando",
      a11y: predicted ? "Previsão: chega agora. Não é uma posição ao vivo." : "Chega agora, ao vivo.",
    };
  }
  if (seconds < 3600) {
    const minutes = Math.ceil(seconds / 60);
    return {
      primary: `${prefix}${minutes} min`,
      secondary: formatClock(arrival.at),
      a11y: predicted
        ? `Previsão: chega em cerca de ${minutes} ${minutesWord(minutes)}. Não é uma posição ao vivo.`
        : `Chega em ${minutes} ${minutesWord(minutes)}, ao vivo.`,
    };
  }
  const minutes = Math.ceil(seconds / 60);
  return {
    primary: `${prefix}${formatHours(minutes)}`,
    secondary: formatClock(arrival.at),
    a11y: predicted ? `Previsão: chega em ${formatHours(minutes)}. Não é uma posição ao vivo.` : `Chega em ${formatHours(minutes)}, ao vivo.`,
  };
}

function scheduledFormat(arrival: ArrivalVM, now: Date): EtaFormat {
  if (isSameMinute(arrival.at, now)) {
    return {
      primary: formatClock(arrival.at),
      secondary: "agora",
      a11y: `Próxima saída às ${formatClock(arrival.at)}, agora. Horário previsto pela tabela.`,
    };
  }
  const minutes = minutesUntilClock(arrival.at, now);
  if (minutes <= 0) {
    return {
      primary: formatClock(arrival.at),
      secondary: "já saiu",
      a11y: `Saída às ${formatClock(arrival.at)}, já saiu.`,
    };
  }
  return {
    primary: formatClock(arrival.at),
    secondary: minutes < 60 ? `em ${minutes} min` : `em ${formatHours(minutes)}`,
    a11y: `Próxima saída às ${formatClock(arrival.at)}, em ${minutes} minutos. Horário previsto pela tabela.`,
  };
}

function staleFormat(arrival: ArrivalVM, now: Date): EtaFormat {
  const ageS = Math.abs(Math.floor((now.getTime() - arrival.asOf.getTime()) / 1000));
  if (ageS < 60) {
    return { primary: `há ${ageS} s`, secondary: "Última posição", a11y: `Última posição há ${ageS} segundos.` };
  }
  const minutes = Math.ceil(ageS / 60);
  const word = minutes === 1 ? "minuto" : "minutos";
  return { primary: `há ${minutes} min`, secondary: "Última posição", a11y: `Última posição há ${minutes} ${word}.` };
}